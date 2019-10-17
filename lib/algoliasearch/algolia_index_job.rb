module AlgoliaSearch
  class AlgoliaIndexJob < ::ActiveJob::Base
    queue_as :algoliasearch

    def perform(record)
      record.class.algolia_index!(record)
    end
  end
end
