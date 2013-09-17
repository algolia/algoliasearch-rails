Algolia Search for Rails
==================

This gem let you easily integrate the Algolia Search API to your favorite ORM. It's based on the [algoliasearch-client-ruby](https://github.com/algolia/algoliasearch-client-ruby) gem.

Table of Content
-------------
**Get started**

1. [Install](#install) 
1. [Setup](#setup) 
1. [Quick Start](#quick-start)
1. [Options](#options)
1. [Search settings](#search-settings)

Install
-------------

```ruby
gem "algoliasearch-rails"
```

Setup
-------------
Create a new file <code>config/initializers/algoliasearch.rb</code> to setup your APPLICATION_ID and API_KEY. aassdd


```ruby
AlgoliaSearch.configuration = { application_id: 'YourApplicationID', api_key: 'YourAPIKey' }
```

Quick Start
-------------

The following code will create a <code>contact</code> index if it doesn't exist yet and add search capabilities to your <code>Contact</code> class:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    attribute :first_name, :last_name, :email
  end
end
```

Each time a record is saved; it will be - synchronously - indexed. In the other hand, each time a record is destroyed, it will be - synchronoulsy - removed from the index.

```ruby
p Contact.search("jon doe")
```

Options
----------

You can disable auto-indexing and auto-removing setting the following options:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch auto_index: false, auto_remove: false do
    attribute :first_name, :last_name, :email
  end
end
```

Search settings
----------

All search settings can be specified either statically in your model or dynamically at search time:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch auto_index: false, auto_remove: false do
    attribute :first_name, :last_name, :email
    minWordSizeForApprox1 2
    minWordSizeForApprox2 5
    hitsPerPage 42
  end
end
```

```ruby
p Contact.search("jon doe", minWordSizeForApprox1: 2, minWordSizeForApprox2: 5, hitsPerPage: 42)
```
