require 'rubygems'
require 'bundler'
require 'timeout'

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

  c.around(:each) do |example|
    Timeout::timeout(120) {
      example.run
    }
  end

  # Remove all indexes setup in this run in local or CI
  c.after(:suite) do
    safe_index_list.each do |index|
      Algolia.client.delete_index!(index['name'])
    end
  end

  # Before each example connect to the default db
  c.before(:each) do
    connect_to_db()
  end

  # Before each example marked `mocked_db: true` switch database
  c.before(:each, mocked_db: true) do
    connect_to_db("mock")
  end
end

# A unique prefix for your test run in local or CI
SAFE_INDEX_PREFIX = "rails_#{SecureRandom.hex(8)}".freeze

# avoid concurrent access to the same index in local or CI
def safe_index_name(name)
  "#{SAFE_INDEX_PREFIX}_#{name}"
end

# get a list of safe indexes in local or CI
def safe_index_list
  list = Algolia.client.list_indexes()['items']
  list = list.select { |index| index["name"].include?(SAFE_INDEX_PREFIX) }
  list.sort_by { |index| index["primary"] || "" }
end

# Perform database switching in specs so that unit specs can be
# seperated from integration specs in the same run
def connect_to_db(name = "data")
  ActiveRecord::Base.establish_connection(
    'adapter' => defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3',
    'database' => "#{name}.sqlite3",
    'pool' => 5,
    'timeout' => 5000
  )
end
