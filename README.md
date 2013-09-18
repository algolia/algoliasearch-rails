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
1. [Indexing](#indexing)
1. [Search settings](#search-settings)
1. [Note on testing](#note-on-testing)

Install
-------------

```sh
gem install algoliasearch-rails
```

If you are using Rails 3, add the gem to your <code>Gemfile</code>:

```ruby
gem "algoliasearch-rails"
```

And run:

```sh
bundle install
```

Setup
-------------
Create a new file <code>config/initializers/algoliasearch.rb</code> to setup your <code>APPLICATION_ID</code> and <code>API_KEY</code>.


```ruby
AlgoliaSearch.configuration = { application_id: 'YourApplicationID', api_key: 'YourAPIKey' }
```

We support both <code>:will_paginate</code> and <code>:kaminari</code> as pagination backend. For example to use WillPaginate, specify the <code>:pagination_backend</code> as follow:

```ruby
AlgoliaSearch.configuration = { application_id: 'YourApplicationID', api_key: 'YourAPIKey', pagination_backend: :will_paginate }
```

Quick Start
-------------

The following code will create a <code>contact</code> index and add search capabilities to your <code>Contact</code> class:

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

You can force indexing and removing to be asynchronous by setting the following option:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch synchronous: false do
    attribute :first_name, :last_name, :email
  end
end
```

Indexing
---------

You can trigger indexing using the <code>index!</code> instance method.

```ruby
c = Contact.create!(params[:contact])
c.index!
```

And trigger index removing using the <code>remove_from_index!</code> instance method.

```ruby
c.remove_from_index!
c.destroy
```

To reindex all your records, use:

```ruby
Contact.reindex!
```

To clear an index, use:

```ruby
Contact.clear_index!
```


Search settings
----------

All [settings](https://github.com/algolia/algoliasearch-client-ruby#index-settings) can be specified either statically in your model or dynamically at search time using [search options](https://github.com/algolia/algoliasearch-client-ruby#search):

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
p Contact.search("jon doe", minWordSizeForApprox1: 2, minWordSizeForApprox2: 5, hitsPerPage: 42, page: 2)
```

Note on testing
-----------------

To run the specs, please set the <code>ALGOLIA_APPLICATION_ID</code> and <code>ALGOLIA_API_KEY</code> environment variables. Since the tests are creating and removing indexes, DO NOT use your production account.
