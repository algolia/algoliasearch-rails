require 'algoliasearch/safe_index'
require 'algoliasearch/search_options'
require 'algoliasearch/utilities'

module AlgoliaSearch
  class IndexActions

    class << self

      def remove(model_class_name, object_id, index_configurations, synchronous = false)
        return if SearchOptions.auto_index_disabled?(model_class_name)
        raise ArgumentError.new("Cannot index a record with a blank objectID") if object_id.blank?

        index_configurations.each do |options, settings|
          unless options.instance_of?(SearchOptions)
            options = SearchOptions.new(model_class_name, options)
          end

          next if options.indexing_disabled?
          next if options[:slave] || options[:replica]

          index = ensure_init(model_class_name, options, settings)

          if synchronous || options[:synchronous]
            index.delete_object!(object_id)
          else
            index.delete_object(object_id)
          end
        end

        nil
      end

      def ensure_init(model_class_name, options, settings, index_settings = nil)
        unless options.instance_of?(SearchOptions)
          options = SearchOptions.new(model_class_name, options)
        end

        safe_index = SafeIndex.new(
          options.index_name,
          options[:raise_on_failure]
        )

        current_settings = safe_index.get_settings(:getVersion => 1) rescue nil # if the index doesn't exist

        index_settings ||= settings.to_settings
        index_settings = options[:primary_settings].to_settings.merge(index_settings) if options[:inherit]

        options[:check_settings] = true if options[:check_settings].nil?

        if !options.indexing_disabled? && options[:check_settings] && Utilities.settings_changed?(current_settings, index_settings)
          used_slaves = !current_settings.nil? && !current_settings['slaves'].nil?
          replicas = index_settings.delete(:replicas) ||
                     index_settings.delete('replicas') ||
                     index_settings.delete(:slaves) ||
                     index_settings.delete('slaves')
          index_settings[used_slaves ? :slaves : :replicas] = replicas unless replicas.nil? || options[:inherit]
          safe_index.set_settings(index_settings)
        end

        safe_index
      end

    end

  end
end
