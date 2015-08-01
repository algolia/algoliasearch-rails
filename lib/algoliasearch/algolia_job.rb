module AlgoliaSearch
  class AlgoliaJob < ::ActiveJob::Base
    queue_as :algoliasearch

    def perform(record, method)
      record.send(method)
    end
  end
end
