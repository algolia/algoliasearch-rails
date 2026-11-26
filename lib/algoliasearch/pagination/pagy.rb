unless defined? Pagy
  raise(AlgoliaSearch::BadConfiguration, "AlgoliaSearch: Please add 'pagy' to your Gemfile to use Pagy pagination backend")
end

module AlgoliaSearch
  module Pagination
    class Pagy

      def self.create(results, total_hits, options = {})
        pagy_version = Gem::Version.new(::Pagy::VERSION)
        pagy = if pagy_version >= Gem::Version.new('43.0')
                 # Pagy 43 moved offset pagination to Pagy::Offset and renamed `items` to `limit`
                 ::Pagy::Offset.new(count: total_hits, page: options[:page], limit: options[:per_page])
               elsif pagy_version >= Gem::Version.new('9.0')
                 ::Pagy.new(count: total_hits, page: options[:page], limit: options[:per_page])
               else
                 ::Pagy.new(count: total_hits, page: options[:page], items: options[:per_page])
               end

        [pagy, results]
      end
    end

  end
end

