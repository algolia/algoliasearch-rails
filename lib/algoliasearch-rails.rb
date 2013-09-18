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
    OPTIONS = [:attributesToIndex, :minWordSizeForApprox1,
      :minWordSizeForApprox2, :hitsPerPage, :attributesToRetrieve,
      :attributesToHighlight, :attributesToSnippet, :attributesToIndex,
      :ranking, :customRanking, :queryType]

    attr_accessor *OPTIONS

    def initialize(block)
      instance_exec(&block) if block
    end

    def attribute(*names)
      @attributesToIndex ||= []
      @attributesToIndex += names.map { |name| name.to_s }
    end

    def to_settings
      settings = {}
      OPTIONS.each do |k|
        v = send(k)
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
        after_save :perform_index_tasks if respond_to?(:after_save)
      end
      unless options[:auto_remove] == false
        after_destroy { |searchable| searchable.remove_from_index! } if respond_to?(:after_destroy)
      end

      @options = { type: model_name, per_page: @index_options.hitsPerPage || 10, page: 1 }.merge(options)
      init
    end

    def reindex!(batch_size = 1000, synchronous = true)
      find_in_batches(batch_size: batch_size) do |group|
        objects = group.map { |o| o.attributes.merge 'objectID' => o.id.to_s }
        if synchronous == true
          @index.save_objects!(objects)
        else
          @index.save_objects(objects)
        end
      end
    end

    def index!(object, synchronous = true)
      if synchronous
        @index.add_object!(object, object.id.to_s)
      else
        @index.add_object(object, object.id.to_s)
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
      @index.delete
      @index = nil
      init
    end

    def search(q, settings = {})
      json = @index.search(q, Hash[settings.map { |k,v| [k.to_s, v.to_s] }])
      results = json['hits'].map do |hit|
        o = Object.const_get(@options[:type]).find(hit['id'])
        o.highlight_result = hit['_highlightResult']
        o
      end
      AlgoliaSearch::Pagination.create(results, json['nbHits'].to_i, @options)
    end

    def init
      @index ||= Algolia::Index.new(model_name)
      @index.set_settings(@index_options.to_settings)
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

    def perform_index_tasks
      return if !@auto_indexing
      index!
      remove_instance_variable :@auto_indexing
      remove_instance_variable :@synchronous
    end
  end
end
