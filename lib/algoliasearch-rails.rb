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

      klass.send :include, InstanceMethods
      klass.extend ClassMethods
    end

  end

  class IndexSettings

    # AlgoliaSearch settings
    OPTIONS = [:attributesToIndex, :minWordSizefor1Typo,
      :minWordSizefor2Typos, :hitsPerPage, :attributesToRetrieve,
      :attributesToHighlight, :attributesToSnippet, :attributesToIndex,
      :ranking, :customRanking, :queryType, :attributesForFaceting,
      :separatorsToIndex, :optionalWords]
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
        @attributes[name] = block_given? ? Proc.new { |o| o.instance_eval(&block) } : Proc.new { |o| o.send(name) }
      end
    end

    def get_attributes(object)
      return object.attributes if @attributes.nil? or @attributes.length == 0
      Hash[@attributes.map { |name, value| [name.to_s, value.call(object) ] }]
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

    def algoliasearch(options = {}, &block)
      @index_settings = IndexSettings.new(block_given? ? Proc.new : nil)
      @settings = @index_settings.to_settings
      @options = { type: full_const_get(model_name.to_s), per_page: @index_settings.get_setting(:hitsPerPage) || 10, page: 1 }.merge(options)

      attr_accessor :highlight_result

      if options[:synchronous] == true
        after_validation :mark_synchronous if respond_to?(:before_validation)
      end
      unless options[:auto_index] == false
        after_validation :mark_must_reindex if respond_to?(:after_validation)
        before_save :mark_for_auto_indexing if respond_to?(:before_save)
        after_save :perform_index_tasks if respond_to?(:after_save)
      end
      unless options[:auto_remove] == false
        after_destroy { |searchable| searchable.remove_from_index! } if respond_to?(:after_destroy)
      end
    end

    def without_auto_index(&block)
      @without_auto_index_scope = true
      begin
        yield
      ensure
        @without_auto_index_scope = false
      end
    end

    def reindex!(batch_size = 1000, synchronous = false)
      return if @without_auto_index_scope
      ensure_init
      last_task = nil
      find_in_batches(batch_size: batch_size) do |group|
        objects = group.map { |o| @index_settings.get_attributes(o).merge 'objectID' => object_id_of(o) }
        last_task = @index.save_objects(objects)
      end
      @index.wait_task(last_task["taskID"]) if last_task and synchronous == true
    end

    def index!(object, synchronous = false)
      return if @without_auto_index_scope
      ensure_init
      if synchronous
        @index.add_object!(@index_settings.get_attributes(object), object_id_of(object))
      else
        @index.add_object(@index_settings.get_attributes(object), object_id_of(object))
      end
    end

    def remove_from_index!(object, synchronous = false)
      return if @without_auto_index_scope
      ensure_init
      if synchronous
        @index.delete_object!(object_id_of(object))
      else
        @index.delete_object(object_id_of(object))
      end
    end

    def clear_index!(synchronous = false)
      ensure_init
      synchronous ? @index.clear! : @index.clear
      @index = nil
    end

    def search(q, settings = {})
      ensure_init
      json = @index.search(q, Hash[settings.map { |k,v| [k.to_s, v.to_s] }])
      results = json['hits'].map do |hit|
        o = @options[:type].where(object_id_method => hit['objectID']).first
        o.highlight_result = hit['_highlightResult']
        o
      end
      AlgoliaSearch::Pagination.create(results, json['nbHits'].to_i, @options)
    end

    def ensure_init
      return if @index
      @index = Algolia::Index.new(index_name)
      current_settings = @index.get_settings rescue nil # if the index doesn't exist
      @index.set_settings(@settings) if index_settings_changed?(current_settings, @settings)
    end

    def index
      ensure_init
      @index
    end

    def must_reindex?(object)
      return true if object_id_changed?(object)
      @index_settings.get_attributes(object).each do |k, v|
        changed_method = "#{k}_changed?"
        return true if object.respond_to?(changed_method) && object.send(changed_method)
      end
      return false
    end

    def index_name
      name = @options[:index_name] || model_name.to_s.gsub('::', '_')
      name = "#{name}_#{Rails.env.to_s}" if @options[:per_environment]
      name
    end

    private

    def object_id_method
      @options[:id] || @options[:object_id] || :id
    end

    def object_id_of(o)
      o.send(object_id_method).to_s
    end

    def object_id_changed?(o)
      m = "#{object_id_method}_changed?"
      o.respond_to?(m) ? o.send(m) : false
    end

    def index_settings_changed?(prev, current)
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

    def full_const_get(name)
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

  end

  # these are the instance methods included
  module InstanceMethods
    def index!
      self.class.index!(self, synchronous?)
    end

    def remove_from_index!
      self.class.remove_from_index!(self, synchronous?)
    end

    private

    def synchronous?
      @synchronous == true
    end

    def mark_synchronous
      @synchronous = true
    end

    def mark_for_auto_indexing
      @auto_indexing = true
    end

    def mark_must_reindex
      @must_reindex = new_record? || self.class.must_reindex?(self)
      true
    end

    def perform_index_tasks
      return if !@auto_indexing || @must_reindex == false
      index!
      remove_instance_variable(:@auto_indexing) if instance_variable_defined?(:@auto_indexing)
      remove_instance_variable(:@synchronous) if instance_variable_defined?(:@synchronous)
      remove_instance_variable(:@must_reindex) if instance_variable_defined?(:@must_reindex)
    end
  end
end
