module AlgoliaSearch
  class AlgoliaJob < ::ActiveJob::Base
    queue_as :algoliasearch

    def perform(record_class, record_or_object_id, remove)
      if remove
        object_id = record_or_object_id
        record_class.constantize.algolia_remove_from_index!(object_id)
      else
        record = record_or_object_id
        record.algolia_index!
      end
    end
  end
end
