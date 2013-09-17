module AlgoliaSearch
  module Configuration
    def configuration
      @@configuration || raise(NotConfigured, "Please configure AlgoliaSearch. Set AlgoliaSearch.configuration = {application_id: 'YOUR_APPLICATION_ID', api_key: 'YOUR_API_KEY'}")
    end

    def configuration=(new_configuration)
      # the default pagination backend is WillPaginate
      @@configuration = new_configuration.tap do |_config|
        _config.replace({ :pagination_backend => :will_paginate }.merge(_config)) if _config.is_a?(Hash)
      end
      Algolia.init application_id: @@configuration[:application_id], api_key: @@configuration[:api_key]
    end
  end
end
