module AlgoliaSearch
  module Configuration
    def configuration
      @@configuration || raise(NotConfigured, "Please configure AlgoliaSearch. Set AlgoliaSearch.configuration = {application_id: 'YOUR_APPLICATION_ID', api_key: 'YOUR_API_KEY'}")
    end

    def configuration=(configuration)
      @@configuration = configuration
      Algolia.init application_id: @@configuration[:application_id], api_key: @@configuration[:api_key]
    end
  end
end
