require "algoliasearch/database_adapter"
require "algoliasearch/database_adapter/active_record"

require "support/database_adapter"

## Adapters will use methods defined on the ORM
#
# We should not test too deeply these methods, but
# only assert any logical flow on the adapter

RSpec.describe DatabaseAdapter::ActiveRecord do
  it_behaves_like "database_adapter"
end
