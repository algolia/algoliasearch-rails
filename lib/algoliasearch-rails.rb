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
    OPTIONS = [:minWordSizefor1Typo, :minWordSizefor2Typos,
      :hitsPerPage, :attributesToRetrieve,
      :attributesToHighlight, :attributesToSnippet, :attributesToIndex,
      :highlightPreTag, :highlightPostTag,
      :ranking, :customRanking, :queryType, :attributesForFaceting,
      :separatorsToIndex, :optionalWords, :attributeForDistinct,
      :synonyms, :placeholders]
    OPTIONS.each do |k|
      define_method k do |v|
        instance_variable_set("@#{k}", v)
      end
    end

    def initialize(options, block)
      @options = options
      instance_exec(&block) if block
    end

    def attribute(*names, &block)
      raise ArgumentError.new('Cannot pass multiple attribute names if block given') if block_given? and names.length > 1
      raise ArgumentError.new('Cannot specify additional attributes on a slave index') if @options[:slave]
      @attributes ||= {}
      names.each do |name|
        @attributes[name.to_s] = block_given? ? Proc.new { |o| o.instance_eval(&block) } : Proc.new { |o| o.send(name) }
      end
    end
    alias :attributes :attribute

    def add_attribute(*names, &block)
      raise ArgumentError.new('Cannot pass multiple attribute names if block given') if block_given? and names.length > 1
      raise ArgumentError.new('Cannot specify additional attributes on a slave index') if @options[:slave]
      @additional_attributes ||= {}
      names.each do |name|
        @additional_attributes[name.to_s] = block_given? ? Proc.new { |o| o.instance_eval(&block) } : Proc.new { |o| o.send(name) }
      end
    end
    alias :add_attributes :add_attribute

    def get_attributes(object)
      clazz = object.class
      attributes = if defined?(::Mongoid::Document) && clazz.include?(::Mongoid::Document)
        # work-around mongoid 2.4's unscoped method, not accepting a block
        res = @attributes.nil? || @attributes.length == 0 ? object.attributes :
          Hash[@attributes.map { |name, value| [name.to_s, value.call(object) ] }]
        @additional_attributes.each { |name, value| res[name.to_s] = value.call(object) } if @additional_attributes
        res
      else
        object.class.unscoped do
          res = @attributes.nil? || @attributes.length == 0 ? object.attributes :
            Hash[@attributes.map { |name, value| [name.to_s, value.call(object) ] }]
          @additional_attributes.each { |name, value| res[name.to_s] = value.call(object) } if @additional_attributes
          res
        end
      end

      if @options[:sanitize]
        sanitizer = HTML::FullSanitizer.new
        attributes = sanitize_attributes(attributes, sanitizer)
      end

      if @options[:force_utf8_encoding] && Object.const_defined?(:RUBY_VERSION) && RUBY_VERSION.to_f > 1.8
        attributes = encode_attributes(attributes)
      end

      attributes
    end

    def sanitize_attributes(v, sanitizer)
      case v
      when String
        sanitizer.sanitize(v)
      when Hash
        v.each { |key, value| v[key] = sanitize_attributes(value, sanitizer) }
      when Array
        v.map { |x| sanitize_attributes(x, sanitizer) }
      else
        v
      end
    end

    def encode_attributes(v)
      case v
      when String
        v.force_encoding('utf-8')
      when Hash
        v.each { |key, value| v[key] = encode_attributes(value) }
      when Array
        v.map { |x| encode_attributes(x) }
      else
        v
      end
    end

    def geoloc(lat_attr, lng_attr)
      raise ArgumentError.new('Cannot specify additional attributes on a slave index') if @options[:slave]
      add_attribute :_geoloc do |o|
        { :lat => o.send(lat_attr).to_f, :lng => o.send(lng_attr).to_f }
      end
    end

    def tags(*args, &block)
      raise ArgumentError.new('Cannot specify additional attributes on a slave index') if @options[:slave]
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
      settings[:slaves] = additional_indexes.select { |options, s| options[:slave] }.map do |options, s|
        name = options[:index_name]
        name = "#{name}_#{Rails.env.to_s}" if options[:per_environment]
        name
      end if !@options[:slave]
      settings
    end

    def add_index(index_name, options = {}, &block)
      raise ArgumentError.new('Cannot specify additional index on a slave index') if @options[:slave]
      raise ArgumentError.new('No block given') if !block_given?
      raise ArgumentError.new('Options auto_index and auto_remove cannot be set on nested indexes') if options[:auto_index] || options[:auto_remove]
      options[:index_name] = index_name
      @additional_indexes ||= {}
      @additional_indexes[options] = IndexSettings.new(options, Proc.new)
    end

    def add_slave(index_name, options = {}, &block)
      raise ArgumentError.new('Cannot specify additional slaves on a slave index') if @options[:slave]
      raise ArgumentError.new('No block given') if !block_given?
      add_index(index_name, options.merge({ :slave => true }), &block)
    end

    def additional_indexes
      @additional_indexes || {}
    end
  end

  # these are the class methods added when AlgoliaSearch is included
  module ClassMethods

    def self.extended(base)
      class <<base
        alias_method :without_auto_index, :algolia_without_auto_index unless method_defined? :without_auto_index
        alias_method :reindex!, :algolia_reindex! unless method_defined? :reindex!
        alias_method :reindex, :algolia_reindex unless method_defined? :reindex
        alias_method :index_objects, :algolia_index_objects unless method_defined? :index_objects
        alias_method :index!, :algolia_index! unless method_defined? :index!
        alias_method :remove_from_index!, :algolia_remove_from_index! unless method_defined? :remove_from_index!
        alias_method :clear_index!, :algolia_clear_index! unless method_defined? :clear_index!
        alias_method :search, :algolia_search unless method_defined? :search
        alias_method :raw_search, :algolia_raw_search unless method_defined? :raw_search
        alias_method :index, :algolia_index unless method_defined? :index
        alias_method :index_name, :algolia_index_name unless method_defined? :index_name
        alias_method :must_reindex?, :algolia_must_reindex? unless method_defined? :must_reindex?
      end

      base.cattr_accessor :algoliasearch_options, :algoliasearch_settings
    end

    def algoliasearch(options = {}, &block)
      self.algoliasearch_settings = IndexSettings.new(options, block_given? ? Proc.new : nil)
      self.algoliasearch_options = { :type => algolia_full_const_get(model_name.to_s), :per_page => algoliasearch_settings.get_setting(:hitsPerPage) || 10, :page => 1 }.merge(options)

      attr_accessor :highlight_result

      if options[:synchronous] == true
        after_validation :algolia_mark_synchronous if respond_to?(:after_validation)
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
      algolia_configurations.each do |options, settings|
        next if algolia_indexing_disabled?(options)
        index = algolia_ensure_init(options, settings)
        next if options[:slave]
        last_task = nil

        algolia_find_in_batches(batch_size) do |group|
          if algolia_conditional_index?(options)
            # delete non-indexable objects
            objects = group.select { |o| !algolia_indexable?(o, options) }.map { |o| algolia_object_id_of(o, options) }
            index.delete_objects(objects)
            # select only indexable objects  
            group = group.select { |o| algolia_indexable?(o, options) }
          end
          objects = group.map { |o| settings.get_attributes(o).merge 'objectID' => algolia_object_id_of(o, options) }
          last_task = index.save_objects(objects)
        end

        index.wait_task(last_task["taskID"]) if last_task and synchronous == true
      end
      nil
    end

    # reindex whole database using a extra temporary index + move operation
    def algolia_reindex(batch_size = 1000, synchronous = false)
      return if @algolia_without_auto_index_scope
      algolia_configurations.each do |options, settings|
        next if algolia_indexing_disabled?(options)
        next if options[:slave]

        # fetch the master settings
        master_index = algolia_ensure_init(options, settings)
        master_settings = master_index.get_settings rescue {} # if master doesn't exist yet
        master_settings.merge!(JSON.parse(settings.to_settings.to_json)) # convert symbols to strings

        # remove the slaves of the temporary index
        master_settings.delete :slaves
        master_settings.delete 'slaves'

        # init temporary index
        index_name = algolia_index_name(options)
        tmp_options = options.merge({ :index_name => "#{index_name}.tmp" })
        tmp_settings = settings.dup
        tmp_index = algolia_ensure_init(tmp_options, tmp_settings, master_settings)

        algolia_find_in_batches(batch_size) do |group|
          if algolia_conditional_index?(tmp_options)
            # select only indexable objects
            group = group.select { |o| algolia_indexable?(o, tmp_options) }
          end
          objects = group.map { |o| tmp_settings.get_attributes(o).merge 'objectID' => algolia_object_id_of(o, tmp_options) }
          tmp_index.save_objects(objects)
        end

        move_task = ::Algolia.move_index(tmp_index.name, index_name)
        tmp_index.wait_task(move_task["taskID"]) if synchronous == true
      end
      nil
    end

    def algolia_index_objects(objects, synchronous = false)
      algolia_configurations.each do |options, settings|
        next if algolia_indexing_disabled?(options)
        index = algolia_ensure_init(options, settings)
        next if options[:slave]
        task = index.save_objects(objects.map { |o| settings.get_attributes(o).merge 'objectID' => algolia_object_id_of(o, options) })
        index.wait_task(task["taskID"]) if synchronous == true
      end
    end

    def algolia_index!(object, synchronous = false)
      return if @algolia_without_auto_index_scope
      algolia_configurations.each do |options, settings|
        next if algolia_indexing_disabled?(options)
        object_id = algolia_object_id_of(object, options)
        raise ArgumentError.new("Cannot index a blank objectID") if object_id.blank?
        index = algolia_ensure_init(options, settings)
        next if options[:slave]
        if algolia_indexable?(object, options)
          if synchronous
            index.add_object!(settings.get_attributes(object), object_id)
          else
            index.add_object(settings.get_attributes(object), object_id)
          end
        elsif algolia_conditional_index?(options)
          # remove non-indexable objects
          if synchronous
            index.delete_object!(object_id)
          else
            index.delete_object(object_id)
          end
        end
      end
      nil
    end

    def algolia_remove_from_index!(object, synchronous = false)
      return if @algolia_without_auto_index_scope
      object_id = algolia_object_id_of(object)
      raise ArgumentError.new("Cannot index a blank objectID") if object_id.blank?
      algolia_configurations.each do |options, settings|
        next if algolia_indexing_disabled?(options)
        index = algolia_ensure_init(options, settings)
        next if options[:slave]
        if synchronous
          index.delete_object!(object_id)
        else
          index.delete_object(object_id)
        end
      end
      nil
    end

    def algolia_clear_index!(synchronous = false)
      algolia_configurations.each do |options, settings|
        next if algolia_indexing_disabled?(options)
        index = algolia_ensure_init(options, settings)
        next if options[:slave]
        synchronous ? index.clear! : index.clear
        @algolia_indexes[settings] = nil
      end
      nil
    end

    def algolia_raw_search(q, params = {})
      index_name = params.delete(:index) || params.delete('index') || params.delete(:slave) || params.delete('slave')
      index = algolia_index(index_name)
      index.search(q, Hash[params.map { |k,v| [k.to_s, v.to_s] }])
    end

    module AdditionalMethods
      def self.extended(base)
        class <<base
          alias_method :raw_answer, :algolia_raw_answer unless method_defined? :raw_answer
          alias_method :facets, :algolia_facets unless method_defined? :facets
        end
      end

      def algolia_raw_answer
        @algolia_json
      end

      def algolia_facets
        @algolia_json['facets']
      end

      private
      def algolia_init_raw_answer(json)
        @algolia_json = json
      end
    end

    def algolia_search(q, params = {})
      if AlgoliaSearch.configuration[:pagination_backend]
        # kaminari and will_paginate start pagination at 1, Algolia starts at 0
        params[:page] = (params.delete('page') || params.delete(:page)).to_i
        params[:page] -= 1 if params[:page].to_i > 0
      end
      json = algolia_raw_search(q, params)
      hit_ids = json['hits'].map { |hit| hit['objectID'] }
      if defined?(::Mongoid::Document) && self.include?(::Mongoid::Document)
        condition_key = algolia_object_id_method.in
      else
        condition_key = algolia_object_id_method
      end
      results_by_id = algoliasearch_options[:type].where(condition_key => hit_ids).index_by do |hit|
        algolia_object_id_of(hit)
      end
      results = json['hits'].map do |hit|
        o = results_by_id[hit['objectID']]
        if o
          o.highlight_result = hit['_highlightResult']
          o
        end
      end.compact
      res = AlgoliaSearch::Pagination.create(results, json['nbHits'].to_i, algoliasearch_options.merge({ :page => json['page'] + 1, :per_page => json['hitsPerPage'] }))
      res.extend(AdditionalMethods)
      res.send(:algolia_init_raw_answer, json)
      res
    end

    def algolia_index(name = nil)
      if name
        algolia_configurations.each do |o, s|
          return algolia_ensure_init(o, s) if o[:index_name].to_s == name.to_s
        end
        raise ArgumentError.new("Invalid index/slave name: #{name}")
      end
      algolia_ensure_init
    end

    def algolia_index_name(options = nil)
      options ||= algoliasearch_options
      name = options[:index_name] || model_name.to_s.gsub('::', '_')
      name = "#{name}_#{Rails.env.to_s}" if options[:per_environment]
      name
    end

    def algolia_must_reindex?(object)
      algolia_configurations.each do |options, settings|
        next if options[:slave]
        return true if algolia_object_id_changed?(object, options)
        settings.get_attributes(object).each do |k, v|
          changed_method = "#{k}_changed?"
          return true if !object.respond_to?(changed_method) || object.send(changed_method)
        end
        [options[:if], options[:unless]].each do |condition|
          case condition
          when nil
          when String, Symbol
            changed_method = "#{condition}_changed?"
            return true if !object.respond_to?(changed_method) || object.send(changed_method)
          else
          end
        end
      end
      return false
    end

    protected

    def algolia_ensure_init(options = nil, settings = nil, index_settings = nil)
      @algolia_indexes ||= {}
      options ||= algoliasearch_options
      settings ||= algoliasearch_settings
      return @algolia_indexes[settings] if @algolia_indexes[settings]
      @algolia_indexes[settings] = Algolia::Index.new(algolia_index_name(options))
      current_settings = @algolia_indexes[settings].get_settings rescue nil # if the index doesn't exist
      if !algolia_indexing_disabled?(options) && (index_settings || algoliasearch_settings_changed?(current_settings, settings.to_settings))
        index_settings ||= settings.to_settings
        @algolia_indexes[settings].set_settings(index_settings)
      end
      @algolia_indexes[settings]
    end

    private

    def algolia_configurations
      if @configurations.nil?
        @configurations = {}
        @configurations[algoliasearch_options] = algoliasearch_settings
        algoliasearch_settings.additional_indexes.each do |k,v|
          @configurations[k] = v
        end
      end
      @configurations
    end

    def algolia_object_id_method(options = nil)
      options ||= algoliasearch_options
      options[:id] || options[:object_id] || :id
    end

    def algolia_object_id_of(o, options = nil)
      o.send(algolia_object_id_method(options)).to_s
    end

    def algolia_object_id_changed?(o, options = nil)
      m = "#{algolia_object_id_method(options)}_changed?"
      o.respond_to?(m) ? o.send(m) : false
    end

    def algoliasearch_settings_changed?(prev, current)
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
      obj = Object.const_defined?(:RUBY_VERSION) && RUBY_VERSION.to_f < 1.9 ? Object : self
      list.each do |x|
        # This is required because const_get tries to look for constants in the
        # ancestor chain, but we only want constants that are HERE
        obj = obj.const_defined?(x) ? obj.const_get(x) : obj.const_missing(x)
      end
      obj
    end

    def algolia_conditional_index?(options = nil)
      options ||= algoliasearch_options
      options[:if].present? || options[:unless].present?
    end

    def algolia_indexable?(object, options = nil)
      options ||= algoliasearch_options
      if_passes = options[:if].blank? || algolia_constraint_passes?(object, options[:if])
      unless_passes = options[:unless].blank? || !algolia_constraint_passes?(object, options[:unless])
      if_passes && unless_passes
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

    def algolia_indexing_disabled?(options = nil)
      options ||= algoliasearch_options
      constraint = options[:disable_indexing] || options['disable_indexing']
      case constraint
      when nil
        return false
      when true, false
        return constraint
      when String, Symbol
        return send(constraint)
      else
        return constraint.call if constraint.respond_to?(:call) # Proc
      end
      raise ArgumentError, "Unknown constraint type: #{constraint} (#{constraint.class})"
    end

    def algolia_find_in_batches(batch_size, &block)
      if (defined?(::ActiveRecord) && ancestors.include?(::ActiveRecord::Base)) || respond_to?(:find_in_batches)
        find_in_batches(:batch_size => batch_size, &block)
      else
        # don't worry, mongoid has its own underlying cursor/streaming mechanism
        items = []
        all.each do |item|
          items << item
          if items.length % batch_size == 0
            yield items
            items = []
          end
        end
        yield items unless items.empty?
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

    def algolia_index!(synchronous = false)
      self.class.algolia_index!(self, synchronous || algolia_synchronous?)
    end

    def algolia_remove_from_index!(synchronous = false)
      self.class.algolia_remove_from_index!(self, synchronous || algolia_synchronous?)
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
