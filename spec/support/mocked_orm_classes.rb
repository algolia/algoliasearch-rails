require "active_record"
require 'sequel'
require "mongoid"

## Active record basic class

# Create a seperate database for mocks (mock.sqlite3)

FileUtils.rm( 'mock.sqlite3' ) rescue nil
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::WARN

if ActiveRecord::Base.respond_to?(:raise_in_transactional_callbacks)
  ActiveRecord::Base.raise_in_transactional_callbacks = true
end

ActiveRecord::Schema.define do
  create_table :simple_active_records do |t|

  end
end

class SimpleActiveRecord < ActiveRecord::Base; end

## Sequel basic class

SEQUEL_MOCK_DB = Sequel.connect(defined?(JRUBY_VERSION) ? 'jdbc:sqlite:sequel_data.sqlite3' : { 'adapter' => 'sqlite', 'database' => 'sequel_data.sqlite3' })

unless SEQUEL_MOCK_DB.table_exists?(:simple_sequels)
  SEQUEL_MOCK_DB.create_table(:simple_sequels) do
    primary_key :id
    String :name
    String :author
    FalseClass :released
    FalseClass :premium
  end
end

class SimpleSequel < Sequel::Model(SEQUEL_MOCK_DB)
  plugin :active_model
end

## Mogoid basic class

class SimpleMongoid
  include ::Mongoid::Document
end
