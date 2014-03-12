unless defined? Kaminari
  raise(AlgoliaSearch::BadConfiguration, "AlgoliaSearch: Please add 'kaminari' to your Gemfile to use kaminari pagination backend")
end

require "kaminari/models/array_extension"

module AlgoliaSearch
  module Pagination
    class Kaminari < ::Kaminari::PaginatableArray

      def initialize(array, options)
        super(array, options)
      end

      def limit(num)
        # noop
        self
      end

      def offset(num)
        # noop
        self
      end

      class << self
        def create(results, total_hits, options = {})
          new results, offset: ((options[:page] - 1) * options[:per_page]), limit: options[:per_page], total_count: total_hits
        end
      end
    end
  end
end
