unless defined? Pagy
  raise(AlgoliaSearch::BadConfiguration, "AlgoliaSearch: Please add 'pagy' to your Gemfile to use Pagy pagination backend")
end

module AlgoliaSearch
  module Pagination
    class Pagy
      include Pagy::Backend if defined? Pagy::Backend

      def self.create(results, total_hits, options = {})
        vars = {
          count: total_hits,
          page: options[:page],
          items: options[:per_page]
        }

        pagy(results, vars)
      end
    end

  end
end

