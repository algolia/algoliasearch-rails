module AlgoliaSearch
  module Pagination

    autoload :WillPaginate, 'algoliasearch/pagination/will_paginate'
    autoload :Kaminari, 'algoliasearch/pagination/kaminari'

    def self.create(results, total_hits, options = {})
      begin
        backend = AlgoliaSearch.configuration[:pagination_backend].to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase } # classify pagination backend name
        page = Object.const_get(:AlgoliaSearch).const_get(:Pagination).const_get(backend).create(results, total_hits, options)
        page
      rescue NameError
        raise(BadConfiguration, "Unknown pagination backend")
      end
    end
    
  end
end
