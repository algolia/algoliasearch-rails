module AlgoliaSearch
  module Configuration
    def initialize
      @client = nil
    end

    def configuration
      @@configuration || raise(NotConfigured, "Please configure AlgoliaSearch. Set AlgoliaSearch.configuration = {application_id: 'YOUR_APPLICATION_ID', api_key: 'YOUR_API_KEY'}")
    end

    def configuration=(configuration)
      @@configuration = default_configuration
                          .merge(configuration)
    end

    def client
      if @client.nil?
        setup_client
      end

      @client
    end

    def setup_client
      @client = Algolia::SearchClient.create(
        @@configuration[:application_id],
        @@configuration[:api_key],
        {
          user_agent_segments: [
            "Algolia for Rails (#{AlgoliaSearch::VERSION})",
            "Rails (#{defined?(::Rails::VERSION::STRING) ? ::Rails::VERSION::STRING : 'unknown'})",
            @@configuration[:append_to_user_agent]
          ].compact
        })
    end

    def default_configuration
      {
        queue_name: 'algoliasearch'
      }
    end
  end
end
