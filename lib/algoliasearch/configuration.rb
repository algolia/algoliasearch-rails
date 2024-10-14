module AlgoliaSearch
  module Configuration
    REQUIRED_CONFIGURATION = {
      user_agent: "Algolia for Rails (#{AlgoliaSearch::VERSION}); Rails (#{defined?(::Rails::VERSION::STRING) ? ::Rails::VERSION::STRING : 'unknown'})",
    }

    def initialize
      @client = nil
    end

    def configuration
      @@configuration || raise(NotConfigured, "Please configure AlgoliaSearch. Set AlgoliaSearch.configuration = {application_id: 'YOUR_APPLICATION_ID', api_key: 'YOUR_API_KEY'}")
    end

    def configuration=(configuration)
      user_agent = [REQUIRED_CONFIGURATION[:user_agent], configuration[:append_to_user_agent]].compact.join('; ')
      @@configuration = default_configuration
                        .merge(configuration)
                        .merge(REQUIRED_CONFIGURATION)
                        .merge({ user_agent: user_agent })
    end

    def client
      if @client.nil?
        setup_client
      end

      @client
    end

    def setup_client
      @client = Algolia::SearchClient.create(@@configuration[:application_id], @@configuration[:api_key])
    end

    def default_configuration
      {
        queue_name: 'algoliasearch'
      }
    end
  end
end
