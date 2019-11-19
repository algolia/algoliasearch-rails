module AlgoliaSearch
  class IndexSettings

    DEFAULT_BATCH_SIZE = 1000

    # AlgoliaSearch settings
    OPTIONS = [
      # Attributes
      :searchableAttributes, :attributesForFaceting, :unretrievableAttributes, :attributesToRetrieve,
      :attributesToIndex, #Legacy name of searchableAttributes
      # Ranking
      :ranking, :customRanking, # Replicas are handled via `add_replica`
      # Faceting
      :maxValuesPerFacet, :sortFacetValuesBy,
      # Highlighting / Snippeting
      :attributesToHighlight, :attributesToSnippet, :highlightPreTag, :highlightPostTag,
      :snippetEllipsisText, :restrictHighlightAndSnippetArrays,
      # Pagination
      :hitsPerPage, :paginationLimitedTo,
      # Typo
      :minWordSizefor1Typo, :minWordSizefor2Typos, :typoTolerance, :allowTyposOnNumericTokens,
      :disableTypoToleranceOnAttributes, :disableTypoToleranceOnWords, :separatorsToIndex,
      # Language
      :ignorePlurals, :removeStopWords, :camelCaseAttributes, :decompoundedAttributes,
      :keepDiacriticsOnCharacters, :queryLanguages,
      # Query Rules
      :enableRules,
      # Query Strategy
      :queryType, :removeWordsIfNoResults, :advancedSyntax, :optionalWords,
      :disablePrefixOnAttributes, :disableExactOnAttributes, :exactOnSingleWordQuery, :alternativesAsExact,
      # Performance
      :numericAttributesForFiltering, :allowCompressionOfIntegerArray,
      :numericAttributesToIndex, # Legacy name of numericAttributesForFiltering
      # Advanced
      :attributeForDistinct, :distinct, :replaceSynonymsInHighlight, :minProximity, :responseFields,
      :maxFacetHits,

      # Rails-specific
      :synonyms, :placeholders, :altCorrections,
    ]

    OPTIONS.each do |k|
      define_method k do |v|
        instance_variable_set("@#{k}", v)
      end
    end

    def initialize(options, block)
      @options = options
      instance_exec(&block) if block
    end

    def use_serializer(serializer)
      @serializer = serializer
      # instance_variable_set("@serializer", serializer)
    end

    def attribute(*names, &block)
      raise ArgumentError.new('Cannot pass multiple attribute names if block given') if block_given? and names.length > 1
      raise ArgumentError.new('Cannot specify additional attributes on a replica index') if @options[:slave] || @options[:replica]
      @attributes ||= {}
      names.flatten.each do |name|
        @attributes[name.to_s] = block_given? ? Proc.new { |o| o.instance_eval(&block) } : Proc.new { |o| o.send(name) }
      end
    end
    alias :attributes :attribute

    def add_attribute(*names, &block)
      raise ArgumentError.new('Cannot pass multiple attribute names if block given') if block_given? and names.length > 1
      raise ArgumentError.new('Cannot specify additional attributes on a replica index') if @options[:slave] || @options[:replica]
      @additional_attributes ||= {}
      names.each do |name|
        @additional_attributes[name.to_s] = block_given? ? Proc.new { |o| o.instance_eval(&block) } : Proc.new { |o| o.send(name) }
      end
    end
    alias :add_attributes :add_attribute

    def is_mongoid?(object)
      defined?(::Mongoid::Document) && object.class.include?(::Mongoid::Document)
    end

    def is_sequel?(object)
      defined?(::Sequel) && object.class < ::Sequel::Model
    end

    def is_active_record?(object)
      !is_mongoid?(object) && !is_sequel?(object)
    end

    def get_default_attributes(object)
      if is_mongoid?(object)
        # work-around mongoid 2.4's unscoped method, not accepting a block
        object.attributes
      elsif is_sequel?(object)
        object.to_hash
      else
        object.class.unscoped do
          object.attributes
        end
      end
    end

    def get_attribute_names(object)
      get_attributes(object).keys
    end

    def attributes_to_hash(attributes, object)
      if attributes
        Hash[attributes.map { |name, value| [name.to_s, value.call(object) ] }]
      else
        {}
      end
    end

    def get_attributes(object)
      # If a serializer is set, we ignore attributes
      # everything should be done via the serializer
      if not @serializer.nil?
        attributes = @serializer.new(object).attributes
      else
        if @attributes.nil? || @attributes.length == 0
          # no `attribute ...` have been configured, use the default attributes of the model
          attributes = get_default_attributes(object)
        else
          # at least 1 `attribute ...` has been configured, therefore use ONLY the one configured
          if is_active_record?(object)
            object.class.unscoped do
              attributes = attributes_to_hash(@attributes, object)
            end
          else
            attributes = attributes_to_hash(@attributes, object)
          end
        end
      end

      attributes.merge!(attributes_to_hash(@additional_attributes, object)) if @additional_attributes

      if @options[:sanitize]
        sanitizer = begin
          ::HTML::FullSanitizer.new
        rescue NameError
          # from rails 4.2
          ::Rails::Html::FullSanitizer.new
        end
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
      raise ArgumentError.new('Cannot specify additional attributes on a replica index') if @options[:slave] || @options[:replica]
      add_attribute :_geoloc do |o|
        { :lat => o.send(lat_attr).to_f, :lng => o.send(lng_attr).to_f }
      end
    end

    def tags(*args, &block)
      raise ArgumentError.new('Cannot specify additional attributes on a replica index') if @options[:slave] || @options[:replica]
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
      if !@options[:slave] && !@options[:replica]
        settings[:slaves] = additional_indexes.select { |opts, s| opts[:slave] }.map do |opts, s|
          name = opts[:index_name]
          name = "#{name}_#{Rails.env.to_s}" if opts[:per_environment]
          name
        end
        settings.delete(:slaves) if settings[:slaves].empty?
        settings[:replicas] = additional_indexes.select { |opts, s| opts[:replica] }.map do |opts, s|
          name = opts[:index_name]
          name = "#{name}_#{Rails.env.to_s}" if opts[:per_environment]
          name
        end
        settings.delete(:replicas) if settings[:replicas].empty?
      end
      settings
    end

    def add_index(index_name, options = {}, &block)
      raise ArgumentError.new('Cannot specify additional index on a replica index') if @options[:slave] || @options[:replica]
      raise ArgumentError.new('No block given') if !block_given?
      raise ArgumentError.new('Options auto_index and auto_remove cannot be set on nested indexes') if options[:auto_index] || options[:auto_remove]
      @additional_indexes ||= {}
      raise MixedSlavesAndReplicas.new('Cannot mix slaves and replicas in the same configuration (add_slave is deprecated)') if (options[:slave] && @additional_indexes.any? { |opts, _| opts[:replica] }) || (options[:replica] && @additional_indexes.any? { |opts, _| opts[:slave] })
      options[:index_name] = index_name
      @additional_indexes[options] = IndexSettings.new(options, Proc.new)
    end

    def add_replica(index_name, options = {}, &block)
      raise ArgumentError.new('Cannot specify additional replicas on a replica index') if @options[:slave] || @options[:replica]
      raise ArgumentError.new('No block given') if !block_given?
      add_index(index_name, options.merge({ :replica => true, :primary_settings => self }), &block)
    end

    def add_slave(index_name, options = {}, &block)
      raise ArgumentError.new('Cannot specify additional slaves on a slave index') if @options[:slave] || @options[:replica]
      raise ArgumentError.new('No block given') if !block_given?
      add_index(index_name, options.merge({ :slave => true, :primary_settings => self }), &block)
    end

    def additional_indexes
      @additional_indexes || {}
    end

  end
end
