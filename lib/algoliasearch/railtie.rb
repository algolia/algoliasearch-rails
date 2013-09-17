require 'rails'

module AlgoliaSearch
  class Railtie < Rails::Railtie
    rake_tasks do
      load "algoliasearch/tasks/algoliasearch.rake"
    end
  end
end
