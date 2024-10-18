Version 3 of the `algoliasearch-rails` gem replaces the Algolia API client version in use from version 2 to version 3.
These versions of the API client differ significantly, so you likely need to make code changes when updating. 
We've tried keeping most of the changes internal, but there are still some breaking changes you need to be aware of when upgrading.

If you encounter any breaking changes to the Rail integration that are not listed here, please open a Pull Request to add them to this list.

## Breaking changes

`algolia_ensure_init` (this method is protected and shouldn't be called manually, but we list it here anyways): the method no longer returns an initialized `index` object as this is not part of the new API client. The method now returns nothing, but it still ensures the index exists and applies settings if needed.

---
`Model.search`, `Model.raw_search`: response keys in the new API client are no longer strings, but are *always* symbols. For example:
```ruby
# Before
results = Product.raw_search('shirt')
p results['hits']

# After
results = Product.raw_search('shirt')
p results[:hits]
```
---
`Model.search_for_facet_values`: this no longer returns an array of hashes, but an array of objects of type `Algolia::Search::FacetHits`:
```ruby
# Before
facets = Color.search_for_facet_values('short_name', 'bl', :query => 'black')
puts facets.first['value']

# After 
facets = Color.search_for_facet_values('short_name', 'bl', :query => 'black')
facets.first.value
```

---
`Model.index_name` takes an additional, optional parameter. You can use this if you want to get the name of one of your replica indices, which ensures the index naming takes configuration that modifies the index name into account.
For example, if you have the `:per_environment` option set to true, it will automatically add the environment name in the index name.
```ruby
def Product
  include AlgoliaSearch
  
  algoliasearch({ per_environment: true }) do
    add_replica 'Suits', per_environment: true do
      # replica settings
    end
  end
  
end
main_index_name = Product.index_name
replica_index_name = Product.index_name('Suits')
```

---
`AlgoliaSearch::Configuration.client_opts`, `AlgoliaSearch::Configuration::REQUIRED_CONFIGURATION` and `AlgoliaSearch::SafeIndex` have been removed. 
If you need to configure the API client other than the ways that are provided now, it's recommended to set up an instance manually.

---
`Model.index` and `Model.algolia_index` have been removed, as there is no notion of an `Index` object in the new version of the API clients. 
Instead, you can use `Model.index_name` to get the name of the index to target, and use this on an instance of the API client directly.

```ruby
# Before
res = Product.index.search('shoe')

# After
res = AlgoliaSearch.client.search_single_index(Product.index_name,  { query: 'shoe' })
```
