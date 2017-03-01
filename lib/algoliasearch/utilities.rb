module AlgoliaSearch
  module Utilities
    class << self
      def get_model_classes
        Rails.application.eager_load! # Ensure all models are loaded (not necessary in production when cache_classes is true).

        ActiveRecord::Base.descendants.select{ |model| model.respond_to?(:reindex) }
      end

      def clear_all_indexes
        get_model_classes.each do |klass|
          klass.clear_index!
        end
      end

      def reindex_all_models
        klasses = get_model_classes

        puts ''
        puts "Reindexing #{klasses.count} models: #{klasses.to_sentence}."
        puts ''
        
        klasses.each do |klass|
          say "#{klass}:"

          say "Reindexing #{klass.count} records...", true

          klass.reindex
        end
      end
    end
  end
end

