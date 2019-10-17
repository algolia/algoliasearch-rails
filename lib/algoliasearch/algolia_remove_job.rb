module AlgoliaSearch
  class AlgoliaRemoveJob < ::ActiveJob::Base
    queue_as :algoliasearch

    def perform(record_id, model_name)
      model_class = model_name.constantize
      model_class.algolia_remove_from_index_by_id!(record_id, model_name)
    end
  end
end
