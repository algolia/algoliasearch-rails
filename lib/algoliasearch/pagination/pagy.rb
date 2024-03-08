unless defined? Pagy
  raise(AlgoliaSearch::BadConfiguration, "AlgoliaSearch: Please add 'pagy' to your Gemfile to use pagy_search pagination backend")
end

module AlgoliaSearch
  module Pagination
    class Pagy
      def self.create(results, total_hits, options = {})
        vars = {}
        vars[:count] = total_hits
        vars[:page] = options[:page]
        vars[:items] = options[:per_page]

        pagy = ::Pagy.new(vars)
        [pagy, results]
      end
    end

  end
end

