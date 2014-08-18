module AlgoliaSearch
  module Utilities
    class << self
      def get_model_classes
        AlgoliaSearch.included_in ? AlgoliaSearch.included_in : []
      end

      def clear_all_indexes
        get_model_classes.each do |klass|
          klass.clear_index!
        end
      end

      def reindex_all_models
        get_model_classes.each do |klass|
          klass.reindex
        end
      end
    end
  end
end

