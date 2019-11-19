module AlgoliaSearch
  class SearchOptions

    class << self
      def disable_auto_index(value, model_name)
        Thread.current["algolia_without_auto_index_scope_for_#{model_name}"] = value
      end

      def auto_index_disabled?(model_name)
        Thread.current["algolia_without_auto_index_scope_for_#{model_name}"]
      end
    end

    def initialize(model_class_name, options_hash)
      @model_class_name = model_class_name
      @options = {}
      @options[model_class_name] = options_hash
    end

    def options
      @options[@model_class_name]
    end

    # delegate every not implmented method to hash
    def method_missing(method, *args)
      return options.send(method, *args) if options.respond_to?(method)
      super
    end

    def indexing_disabled?
      constraint = options[:disable_indexing] || options['disable_indexing']
      case constraint
      when nil
        return false
      when true, false
        return constraint
      when String, Symbol
        return @model_class_name.constantize.send(constraint)
      else
        return constraint.call if constraint.respond_to?(:call) # Proc
      end
      raise ArgumentError, "Unknown constraint type: #{constraint} (#{constraint.class})"
    end

    def index_name
      name = options[:index_name] || @model_class_name
      name = "#{name}_#{Rails.env.to_s}" if options[:per_environment]
      name
    end

  end
end
