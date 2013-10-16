Algolia Search for Rails
==================

This gem let you easily integrate the Algolia Search API to your favorite ORM. It's based on the [algoliasearch-client-ruby](https://github.com/algolia/algoliasearch-client-ruby) gem.

[![Build Status](https://travis-ci.org/algolia/algoliasearch-rails.png?branch=master)](https://travis-ci.org/algolia/algoliasearch-rails) [![Gem Version](https://badge.fury.io/rb/algoliasearch-rails.png)](http://badge.fury.io/rb/algoliasearch-rails) [![Code Climate](https://codeclimate.com/github/algolia/algoliasearch-rails.png)](https://codeclimate.com/github/algolia/algoliasearch-rails)


Table of Content
-------------
**Get started**

1. [Install](#install)
1. [Setup](#setup)
1. [Quick Start](#quick-start)
1. [Options](#options)
1. [Indexing](#indexing)
1. [Search settings](#search-settings)
1. [Typeahead UI](#typeahead-ui)
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

We support both [will_paginate](https://github.com/mislav/will_paginate) and [kaminari](https://github.com/amatsuda/kaminari) as pagination backend. For example to use <code>:will_paginate</code>, specify the <code>:pagination_backend</code> as follow:

```ruby
AlgoliaSearch.configuration = { application_id: 'YourApplicationID', api_key: 'YourAPIKey', pagination_backend: :will_paginate }
```

Quick Start
-------------

The following code will create a <code>contact</code> index and add search capabilities to your <code>Contact</code> model:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    attribute :first_name, :last_name, :email
  end
end
```

You can either specify the attributes to send (here we restrict to <code>:first_name, :last_name, :email</code>) or not (in that case, all attributes are sent).

```ruby
class Product < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    # all attributes will be sent
  end
end
```

```ruby
p Contact.search("jon doe")
```

Options
----------

Each time a record is saved; it will be - asynchronously - indexed. In the other hand, each time a record is destroyed, it will be - asynchronoulsy - removed from the index.

You can disable auto-indexing and auto-removing setting the following options:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch auto_index: false, auto_remove: false do
    attribute :first_name, :last_name, :email
  end
end
```

You can force indexing and removing to be synchronous by setting the following option:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch synchronous: true do
    attribute :first_name, :last_name, :email
  end
end
```

You can force force the index name using the following option:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch index_name: "contacts_#{Rails.env}" do
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

To reindex all your records, use the <code>reindex!</code> class method:

```ruby
Contact.reindex!
```

To clear an index, use the <code>clear_index!</code> class method:

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
p Contact.search("jon doe", hitsPerPage: 5, page: 2)
```

Typeahead UI
-------------

Require ```algolia/algoliasearch.min``` (see [algoliasearch-client-js](https://github.com/algolia/algoliasearch-client-js)) and ```algolia/typeahead.js``` (a modified version of typeahead.js with custom transports, see the [pull request](https://github.com/twitter/typeahead.js/pull/473)) somewhere in your JavaScript manifest, for example in application.js if you are using Rails 3.1+:

```javascript
//= require algolia/algoliasearch.min
//= require algolia/typeahead.min
```

We recommend the usage of [hogan](http://twitter.github.io/hogan.js/), a JavaScript templating engine from Twitter.

```javascript
//= require hogan
```

Turns any ```input[type="text"]``` element into a typeahead, for example:

```javascript
<input name="email" placeholder="test@example.org" id="user_email" />
<script type="text/javascript">
  $(document).ready(function() {
    var client = new AlgoliaSearch('YourApplicationID', 'ReadOnlyApplicationKey');
    $('input#user_email').typeahead({
      name: 'emails',
      remote: client.initIndex('YourIndex').getTypeaheadTransport(),
      engine: Hogan,
      template: '{{{_highlightResult.email.value}}} ({{{_highlightResult.first_name.value}}} {{{_highlightResult.last_name.value}}})',
      valueKey: 'email'
    });
  });
</script>
```


Note on testing
-----------------

To run the specs, please set the <code>ALGOLIA_APPLICATION_ID</code> and <code>ALGOLIA_API_KEY</code> environment variables. Since the tests are creating and removing indexes, DO NOT use your production account.
