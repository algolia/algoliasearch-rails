begin
  require "rubygems"
  require "bundler"

  Bundler.setup :default
rescue => e
  puts "AlgoliaSearch: #{e.message}"
end
require 'algoliasearch'

require 'algoliasearch/utilities'

if defined? Rails
  begin
    require 'algoliasearch/railtie'
  rescue LoadError
  end
end

module AlgoliaSearch

  class NotConfigured < StandardError; end
  class BadConfiguration < StandardError; end
  class NoBlockGiven < StandardError; end

  autoload :Configuration, 'algoliasearch/configuration'
  extend Configuration

  autoload :Pagination, 'algoliasearch/pagination'

  class << self
    attr_reader :included_in

    def included(klass)
      @included_in ||= []
      @included_in << klass
      @included_in.uniq!

      klass.class_eval do
        extend ClassMethods
        include InstanceMethods
      end
    end

  end

  class IndexSettings

    # AlgoliaSearch settings
    OPTIONS = [:attributesToIndex, :minWordSizefor1Typo,
      :minWordSizefor2Typos, :hitsPerPage, :attributesToRetrieve,
      :attributesToHighlight, :attributesToSnippet, :attributesToIndex,
      :ranking, :customRanking, :queryType, :attributesForFaceting,
      :separatorsToIndex, :optionalWords, :attributeForDistinct, :if]
    OPTIONS.each do |k|
      define_method k do |v|
        instance_variable_set("@#{k}", v)
      end
    end

    def initialize(block)
      instance_exec(&block) if block
    end

    def attribute(*names, &block)
      raise ArgumentError.new('Cannot pass multiple attribute names if block given') if block_given? and names.length > 1
      @attributes ||= {}
      names.each do |name|
        @attributes[name.to_s] = block_given? ? Proc.new { |o| o.instance_eval(&block) } : Proc.new { |o| o.send(name) }
      end
    end
    alias :attributes :attribute

    def add_attribute(*names, &block)
      raise ArgumentError.new('Cannot pass multiple attribute names if block given') if block_given? and names.length > 1
      @additional_attributes ||= {}
      names.each do |name|
        @additional_attributes[name.to_s] = block_given? ? Proc.new { |o| o.instance_eval(&block) } : Proc.new { |o| o.send(name) }
      end
    end
    alias :add_attributes :add_attribute

    def get_attributes(object)
      object.class.unscoped do
        res = @attributes.nil? || @attributes.length == 0 ? object.attributes :
          Hash[@attributes.map { |name, value| [name.to_s, value.call(object) ] }]
        @additional_attributes.each { |name, value| res[name.to_s] = value.call(object) } if @additional_attributes
        res
      end
    end

    def geoloc(lat_attr, lng_attr)
      add_attribute :_geoloc do |o|
        { lat: o.send(lat_attr).to_f, lng: o.send(lng_attr).to_f }
      end
    end

    def tags(*args, &block)
      add_attribute :_tags do |o|
        v = block_given? ? o.instance_eval(&block) : args
        v.is_a?(Array) ? v : [v]
      end
    end

    def get_setting(name)
      instance_variable_get("@#{name}")
    end

    def to_settings
      settings = {}
      OPTIONS.each do |k|
        v = get_setting(k)
        settings[k] = v if !v.nil?
      end
      settings
    end
  end

  # these are the class methods added when AlgoliaSearch is included
  module ClassMethods

    def self.extended(base)
      class <<base
        alias_method :without_auto_index, :algolia_without_auto_index unless method_defined? :without_auto_index
        alias_method :reindex!, :algolia_reindex! unless method_defined? :reindex!
        alias_method :index!, :algolia_index! unless method_defined? :index!
        alias_method :remove_from_index!, :algolia_remove_from_index! unless method_defined? :remove_from_index!
        alias_method :clear_index!, :algolia_clear_index! unless method_defined? :clear_index!
        alias_method :search, :algolia_search unless method_defined? :search
        alias_method :index, :algolia_index unless method_defined? :index
        alias_method :index_name, :algolia_index_name unless method_defined? :index_name
        alias_method :must_reindex?, :algolia_must_reindex? unless method_defined? :must_reindex?
      end
    end

    def algoliasearch(options = {}, &block)
      @algolia_index_settings = IndexSettings.new(block_given? ? Proc.new : nil)
      @algolia_settings = @algolia_index_settings.to_settings
      @algolia_options = { type: algolia_full_const_get(model_name.to_s), per_page: @algolia_index_settings.get_setting(:hitsPerPage) || 10, page: 1 }.merge(options)

      attr_accessor :highlight_result

      if options[:synchronous] == true
        after_validation :algolia_mark_synchronous if respond_to?(:before_validation)
      end
      unless options[:auto_index] == false
        after_validation :algolia_mark_must_reindex if respond_to?(:after_validation)
        before_save :algolia_mark_for_auto_indexing if respond_to?(:before_save)
        after_save :algolia_perform_index_tasks if respond_to?(:after_save)
      end
      unless options[:auto_remove] == false
        after_destroy { |searchable| searchable.remove_from_index! } if respond_to?(:after_destroy)
      end
    end

    def algolia_without_auto_index(&block)
      @algolia_without_auto_index_scope = true
      begin
        yield
      ensure
        @algolia_without_auto_index_scope = false
      end
    end

    def algolia_reindex!(batch_size = 1000, synchronous = false)
      return if @algolia_without_auto_index_scope
      algolia_ensure_init
      last_task = nil
      find_in_batches(batch_size: batch_size) do |group|
        selected = @algolia_options[:if].present? ? group.select { |o| algolia_indexable?(o) } : group
        objects = selected.map { |o| @algolia_index_settings.get_attributes(o).merge 'objectID' => algolia_object_id_of(o) }
        last_task = @algolia_index.save_objects(objects)
      end
      @algolia_index.wait_task(last_task["taskID"]) if last_task and synchronous == true
    end

    def algolia_index!(object, synchronous = false)
      return if @algolia_without_auto_index_scope || !algolia_indexable?(object)
      algolia_ensure_init
      if synchronous
        @algolia_index.add_object!(@algolia_index_settings.get_attributes(object), algolia_object_id_of(object))
      else
        @algolia_index.add_object(@algolia_index_settings.get_attributes(object), algolia_object_id_of(object))
      end
    end

    def algolia_indexable?(object)
      if_opt = @algolia_options[:if]
      if_opt.nil? || algolia_constraint_passes?(object, if_opt)
    end

    def algolia_remove_from_index!(object, synchronous = false)
      return if @algolia_without_auto_index_scope
      algolia_ensure_init
      if synchronous
        @algolia_index.delete_object!(algolia_object_id_of(object))
      else
        @algolia_index.delete_object(algolia_object_id_of(object))
      end
    end

    def algolia_clear_index!(synchronous = false)
      algolia_ensure_init
      synchronous ? @algolia_index.clear! : @algolia_index.clear
      @algolia_index = nil
    end

    def algolia_search(q, settings = {})
      algolia_ensure_init
      json = @algolia_index.search(q, Hash[settings.map { |k,v| [k.to_s, v.to_s] }])
      results = json['hits'].map do |hit|
        o = @algolia_options[:type].where(algolia_object_id_method => hit['objectID']).first
        if o
          o.highlight_result = hit['_highlightResult']
          o
        end
      end.compact
      AlgoliaSearch::Pagination.create(results, json['nbHits'].to_i, @algolia_options)
    end

    def algolia_index
      algolia_ensure_init
      @algolia_index
    end

    def algolia_index_name
      name = @algolia_options[:index_name] || model_name.to_s.gsub('::', '_')
      name = "#{name}_#{Rails.env.to_s}" if @algolia_options[:per_environment]
      name
    end

    def algolia_must_reindex?(object)
      return true if algolia_object_id_changed?(object)
      @algolia_index_settings.get_attributes(object).each do |k, v|
        changed_method = "#{k}_changed?"
        return true if object.respond_to?(changed_method) && object.send(changed_method)
      end
      return false
    end

    protected

    def algolia_ensure_init
      return if @algolia_index
      @algolia_index = Algolia::Index.new(algolia_index_name)
      current_settings = @algolia_index.get_settings rescue nil # if the index doesn't exist
      @algolia_index.set_settings(@algolia_settings) if algolia_index_settings_changed?(current_settings, @algolia_settings)
    end

    private

    def algolia_object_id_method
      @algolia_options[:id] || @algolia_options[:object_id] || :id
    end

    def algolia_object_id_of(o)
      o.send(algolia_object_id_method).to_s
    end

    def algolia_object_id_changed?(o)
      m = "#{algolia_object_id_method}_changed?"
      o.respond_to?(m) ? o.send(m) : false
    end

    def algolia_index_settings_changed?(prev, current)
      return true if prev.nil?
      current.each do |k, v|
        prev_v = prev[k.to_s]
        if v.is_a?(Array) and prev_v.is_a?(Array)
          # compare array of strings, avoiding symbols VS strings comparison
          return true if v.map { |x| x.to_s } != prev_v.map { |x| x.to_s }
        else
          return true if prev_v != v
        end
      end
      false
    end

    def algolia_full_const_get(name)
      list = name.split('::')
      list.shift if list.first.blank?
      obj = self
      list.each do |x|
        # This is required because const_get tries to look for constants in the
        # ancestor chain, but we only want constants that are HERE
        obj = obj.const_defined?(x) ? obj.const_get(x) : obj.const_missing(x)
      end
      obj
    end

    def algolia_constraint_passes?(object, constraint)
      case constraint
      when Symbol
        object.send(constraint)
      when String
        object.send(constraint.to_sym)
      when Enumerable
        # All constraints must pass
        constraint.all? { |inner_constraint| algolia_constraint_passes?(object, inner_constraint) }
      else
        if constraint.respond_to?(:call) # Proc
          constraint.call(object)
        else
          raise ArgumentError, "Unknown constraint type: #{constraint} (#{constraint.class})"
        end
      end
    end
  end

  # these are the instance methods included
  module InstanceMethods

    def self.included(base)
      base.instance_eval do
        alias_method :index!, :algolia_index! unless method_defined? :index!
        alias_method :remove_from_index!, :algolia_remove_from_index! unless method_defined? :remove_from_index!
      end
    end

    def algolia_index!
      self.class.algolia_index!(self, algolia_synchronous?)
    end

    def algolia_remove_from_index!
      self.class.algolia_remove_from_index!(self, algolia_synchronous?)
    end

    private

    def algolia_synchronous?
      @algolia_synchronous == true
    end

    def algolia_mark_synchronous
      @algolia_synchronous = true
    end

    def algolia_mark_for_auto_indexing
      @algolia_auto_indexing = true
    end

    def algolia_mark_must_reindex
      @algolia_must_reindex = new_record? || self.class.algolia_must_reindex?(self)
      true
    end

    def algolia_perform_index_tasks
      return if !@algolia_auto_indexing || @algolia_must_reindex == false
      algolia_index!
      remove_instance_variable(:@algolia_auto_indexing) if instance_variable_defined?(:@algolia_auto_indexing)
      remove_instance_variable(:@algolia_synchronous) if instance_variable_defined?(:@algolia_synchronous)
      remove_instance_variable(:@algolia_must_reindex) if instance_variable_defined?(:@algolia_must_reindex)
    end
  end
end
