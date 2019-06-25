module AlgoliaSearch
  module Configuration
    def configuration
      @@configuration || raise(NotConfigured, "Please configure AlgoliaSearch. Set AlgoliaSearch.configuration = {application_id: 'YOUR_APPLICATION_ID', api_key: 'YOUR_API_KEY'}")
    end

    def configuration=(configuration)
      @@configuration = configuration.merge(
          :user_agent => "Algolia for Rails (#{AlgoliaSearch::VERSION}); Rails (#{Rails::VERSION})"
      )
      Algolia.init @@configuration
    end
  end
end
