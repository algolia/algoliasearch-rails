require 'rubygems'
require 'bundler'

Bundler.setup :test

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'algoliasearch-rails'
require 'rspec'
require 'rails/all'

raise "missing ALGOLIA_APPLICATION_ID or ALGOLIA_API_KEY environment variables" if ENV['ALGOLIA_APPLICATION_ID'].nil? || ENV['ALGOLIA_API_KEY'].nil?

Thread.current[:algolia_hosts] = nil

RSpec.configure do |c|
  c.mock_with :rspec
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true
  c.formatter = 'documentation'
end

# avoid concurrent access to the same index
def safe_index_name(name)
  return name if ENV['TRAVIS'].to_s != "true"
  id = ENV['TRAVIS_JOB_NUMBER'].split('.').last
  "#{name}_travis-#{id}"
end
