module AlgoliaSearch
  module Utilities
    class << self
      def get_model_classes
        Rails.application.eager_load! if Rails.application # Ensure all models are loaded (not necessary in production when cache_classes is true).
        AlgoliaSearch.instance_variable_get :@included_in
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
          puts klass
          puts "Reindexing #{klass.count} records..."
          klass.algolia_reindex
        end
      end

      def set_settings_all_models
        klasses = get_model_classes

        puts ''
        puts "Pushing settings for #{klasses.count} models: #{klasses.to_sentence}."
        puts ''

        klasses.each do |klass|
          puts "Pushing #{klass} settings..."
          klass.algolia_set_settings
        end
      end

      def settings_changed?(prev, current)
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

    end
  end
end

