unless defined? Kaminari
  raise(AlgoliaSearch::BadConfiguration, "AlgoliaSearch: Please add 'kaminari' to your Gemfile to use kaminari pagination backend")
end

module AlgoliaSearch
  module Pagination
    class Kaminari < Array
      include ::Kaminari::ConfigurationMethods::ClassMethods
      include ::Kaminari::PageScopeMethods

      attr_reader :limit_value, :offset_value, :total_count

      def initialize(original_array, limit_val, offset_val, total_count)
        @limit_value = limit_val || default_per_page
        @offset_value, @total_count = offset_val, total_count
        super(original_array)
      end

      def page(num = 1)
        self
      end

      def limit(num)
        self
      end

      def current_page
        offset_value+1
      end

      class << self
        def create(results, total_hits, options = {})
          instance = new(results, options[:per_page], options[:page]-1, total_hits)
          instance
        end
      end
    end
  end
end
