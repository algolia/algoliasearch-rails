require "algoliasearch/database_adapter"
require "algoliasearch/database_adapter/mongoid"

require "support/database_adapter"

## Adapters will use methods defined on the ORM
#
# We should not test too deeply these methods, but
# only assert any logical flow on the adapter

RSpec.describe DatabaseAdapter::Mongoid do
  it_behaves_like "database_adapter"
end
