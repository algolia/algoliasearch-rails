require 'rubygems'
require 'bundler'

Bundler.setup :test

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'algoliasearch-rails'
require 'rspec'

raise "missing ALGOLIA_APPLICATION_ID or ALGOLIA_API_KEY environment variables" if ENV['ALGOLIA_APPLICATION_ID'].nil? || ENV['ALGOLIA_API_KEY'].nil?

AlgoliaSearch.configuration = { application_id: ENV['ALGOLIA_APPLICATION_ID'], api_key: ENV['ALGOLIA_API_KEY'] }

RSpec.configure do |c|
  c.mock_with :rspec
end
