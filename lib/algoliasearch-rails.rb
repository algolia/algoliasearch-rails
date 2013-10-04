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

  class IndexOptions

    # AlgoliaSearch settings
    OPTIONS = [:attributesToIndex, :minWordSizeForApprox1,
      :minWordSizeForApprox2, :hitsPerPage, :attributesToRetrieve,
      :attributesToHighlight, :attributesToSnippet, :attributesToIndex,
      :ranking, :customRanking, :queryType]
    OPTIONS.each do |k|
      define_method k do |v|
        instance_variable_set("@#{k}", v)
      end
    end

    # attributes to consider
    attr_accessor :attributes

    def initialize(block)
      instance_exec(&block) if block
    end

    def attribute(*names)
      self.attributes ||= []
      self.attributes += names
    end

    def get(setting)
      instance_variable_get("@#{setting}")
    end

    def to_settings
      settings = {}
      OPTIONS.each do |k|
        v = get(k)
        settings[k] = v if !v.nil?
      end
      settings
    end
  end

  # these are the class methods added when AlgoliaSearch is included
  module ClassMethods
    def algoliasearch(options = {}, &block)
      @index_options = IndexOptions.new(block_given? ? Proc.new : nil)
      attr_accessor :highlight_result

      unless options[:synchronous] == false
        before_save :mark_synchronous if respond_to?(:before_save)
      end
      unless options[:auto_index] == false
        before_save :mark_for_auto_indexing if respond_to?(:before_save)
        after_validation :mark_must_reindex if respond_to?(:after_validation)
        after_save :perform_index_tasks if respond_to?(:after_save)
      end
      unless options[:auto_remove] == false
        after_destroy { |searchable| searchable.remove_from_index! } if respond_to?(:after_destroy)
      end

      @options = { type: model_name, per_page: @index_options.get(:hitsPerPage) || 10, page: 1 }.merge(options)
      init
    end

    def reindex!(batch_size = 1000, synchronous = true)
      last_task = nil
      find_in_batches(batch_size: batch_size) do |group|
        objects = group.map { |o| attributes(o).merge 'objectID' => o.id.to_s }
        last_task = @index.save_objects(objects)
      end
      @index.wait_task(last_task["taskID"]) if last_task and synchronous == true
    end

    def index!(object, synchronous = true)
      if synchronous
        @index.add_object!(attributes(object), object.id.to_s)
      else
        @index.add_object(attributes(object), object.id.to_s)
      end
    end

    def remove_from_index!(object, synchronous = true)
      if synchronous
        @index.delete_object!(object.id.to_s)
      else
        @index.delete_object(object.id.to_s)
      end
    end

    def clear_index!
      @index.delete rescue "already deleted, not fatal"
      @index = nil
      init
    end

    def search(q, settings = {})
      json = @index.search(q, Hash[settings.map { |k,v| [k.to_s, v.to_s] }])
      results = json['hits'].map do |hit|
        o = Object.const_get(@options[:type]).find(hit['objectID'])
        o.highlight_result = hit['_highlightResult']
        o
      end
      AlgoliaSearch::Pagination.create(results, json['nbHits'].to_i, @options)
    end

    def init
      @index ||= Algolia::Index.new(@options[:index_name] || model_name)
      settings = @index_options.to_settings
      @index.set_settings(settings) if !settings.empty?
    end

    def must_reindex?(object)
      return true if object.id_changed?
      attributes(object).each do |k, v|
        changed_method = "#{k}_changed?"
        return true if object.respond_to?(changed_method) && object.send(changed_method)
      end
      return false
    end

    private

    def attributes(object)
      return object.attributes if @index_options.attributes.nil? or @index_options.attributes.length == 0
      Hash[@index_options.attributes.map { |attr| [attr.to_s, object.send(attr)] }]
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
      @synchronous.nil? || @synchronous == true
    end

    def mark_synchronous
      @synchronous = true
    end

    def mark_for_auto_indexing
      @auto_indexing = true
    end

    def mark_must_reindex
      @must_reindex = self.class.must_reindex?(self)
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
