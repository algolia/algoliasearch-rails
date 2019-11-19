module AlgoliaSearch
  class AlgoliaRemoveJob < ::ActiveJob::Base
    queue_as :algoliasearch

    def perform(record_id, model_name)
      model_class = model_name.constantize

      IndexActions.remove(
        model_name,
        record_id,
        model_class.algolia_configurations
      )
    end
  end
end
