Algolia Search for Rails
==================

This gem let you easily integrate the Algolia Search API to your favorite ORM. It's based on the [algoliasearch-client-ruby](https://github.com/algolia/algoliasearch-client-ruby) gem.

You might be interested in the sample Ruby on Rails application providing a ```typeahead.js```-based auto-completion and ```Google```-like instant search: [algoliasearch-rails-example](https://github.com/algolia/algoliasearch-rails-example/).

[![Build Status](https://travis-ci.org/algolia/algoliasearch-rails.png?branch=master)](https://travis-ci.org/algolia/algoliasearch-rails) [![Gem Version](https://badge.fury.io/rb/algoliasearch-rails.png)](http://badge.fury.io/rb/algoliasearch-rails) [![Code Climate](https://codeclimate.com/github/algolia/algoliasearch-rails.png)](https://codeclimate.com/github/algolia/algoliasearch-rails)


Table of Content
-------------
**Get started**

1. [Install](#install)
1. [Setup](#setup)
1. [Quick Start](#quick-start)
1. [Options](#options)
1. [Configuration example](#configuration-example)
1. [Indexing](#indexing)
1. [Master/Slave](#masterslave)
1. [Advanced indexing](#advanced-indexing)
1. [Tags](#tags)
1. [Search](#search)
1. [Faceting](#faceting)
1. [Geo-search](#geo-search)
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

The following code will create a <code>Contact</code> index and add search capabilities to your <code>Contact</code> model:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    attribute :first_name, :last_name, :email
  end
end
```

You can either specify the attributes to send (here we restricted to <code>:first_name, :last_name, :email</code>) or not (in that case, all attributes are sent).

```ruby
class Product < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    # all attributes will be sent
  end
end
```

You can also use the <code>add_attribute</code> method, to send all model attributes + extra ones:

```ruby
class Product < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    # all attributes + extra_attr will be sent
    add_attribute :extra_attr
  end

  def extra_attr
    "extra_val"
  end
end
```

A search returns ORM-compliant objects reloading them from your database.

```ruby
p Contact.search("jon doe")
```

If you want to retrieve the raw JSON answer from the API, without re-loading the objects from the database, you can use:

```ruby
p Contact.raw_search("jon doe")
```

By the way, we recommend the usage of our [JavaScript API Client](https://github.com/algolia/algoliasearch-client-js) to perform queries.

**Notes:** All methods injected by the ```AlgoliaSearch``` include are prefixed by ```algolia_``` and aliased to the associated short names if they aren't already defined.

```ruby
Contact.algolia_reindex! # <=> Contact.reindex!

Contact.algolia_search("jon doe") # <=> Contact.search("jon doe")
```

Options
----------

Each time a record is saved; it will be - asynchronously - indexed. On the other hand, each time a record is destroyed, it will be - asynchronously - removed from the index.

You can disable auto-indexing and auto-removing setting the following options:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch auto_index: false, auto_remove: false do
    attribute :first_name, :last_name, :email
  end
end
```

You can temporary disable auto-indexing using the <code>without_auto_index</code> scope. This is often used for performance reason.

```ruby
Contact.delete_all
Contact.without_auto_index do
  1.upto(10000) { Contact.create! attributes } # inside the block, auto indexing task will noop
end
Contact.reindex! # will use batch operations
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

You can force the index name using the following option:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch index_name: "MyCustomName" do
    attribute :first_name, :last_name, :email
  end
end
```

You can suffix the index name with the current Rails environment using the following option:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch per_environment: true do # index name will be "Contact_#{Rails.env}"
    attribute :first_name, :last_name, :email
  end
end
```

You can use a block to specify a complex attribute value

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    attribute :email
    attribute :full_name do
      "#{first_name} #{last_name}"
    end
  end
end
```

By default, the `objectID` is based on your record's `id`. You can change this behavior specifying the `:id` option (be sure to use a uniq field).

```ruby
class UniqUser < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch id: :uniq_name do
  end
end
```

You can add constraints controlling if a record must be indexed by using options the ```:if``` or ```:unless``` options.

```ruby
class Post < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch if: :published?, unless: :deleted? do
  end

  def published?
    # [...]
  end

  def deleted?
    # [...]
  end
end
```

You can index a subset of your records using either:

```ruby
# will generate batch API calls (recommended)
MyModel.where('updated_at > ?', 10.minutes.ago).reindex!
```

or

```ruby
MyModel.index_objects MyModel.limit(5)
```


Configuration example
---------------------

Here is a real-word configuration example (from [HN Search](https://github.com/algolia/hn-search)):

```ruby
class Item < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch per_environment: true do
    # the list of attributes sent to Algolia's API
    attribute :created_at, :title, :url, :author, :points, :story_text, :comment_text, :author, :num_comments, :story_id, :story_title, :

    # integer version of the created_at datetime field, to use numerical filtering
    attribute :created_at_i do
      created_at.to_i
    end

    # `title` is more important than `{story,comment}_text`, `{story,comment}_text` more than `url`, `url` more than `author`
    # btw, do not take into account position in most fields to avoid first word match boost
    attributesToIndex ['unordered(title)', 'unordered(story_text)', 'unordered(comment_text)', 'unordered(url)', 'author', 'created_at_i']

    # list of attributes to highlight
    attributesToHighlight ['title', 'story_text', 'comment_text', 'url', 'story_url', 'author', 'story_title']

    # tags used for filtering
    tags do
      [item_type, "author_#{author}", "story_#{story_id}"]
    end

    # use associated number of HN points to sort results (last sort criteria)
    customRanking ['desc(points)', 'desc(num_comments)']

    # controls the way results are sorted sorting on the following 4 criteria (one after another)
    # I removed the 'exact' match critera (improve 1-words query relevance, doesn't fit HNSearch needs)
    ranking ['typo', 'proximity', 'attribute', 'custom']

    # google+, $1.5M raises, C#: we love you
    separatorsToIndex '+#$'
  end

  def story_text
    item_type_cd != Item.comment ? text : nil
  end

  def story_title
    comment? && story ? story.title : nil
  end

  def story_url
    comment? && story ? story.url : nil
  end

  def comment_text
    comment? ? text : nil
  end

  def comment?
    item_type_cd == Item.comment
  end

  # [...]
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

Master/slave
---------

You can define slave indexes using the <code>add_slave</code> method.

```ruby
class Book < ActiveRecord::Base
  attr_protected

  include AlgoliaSearch

  algoliasearch do
    attributesToIndex [:name, :author, :editor]

    # define a slave to search by `author` only
    add_slave 'Book_by_author' do
      attributesToIndex [:author]
    end

    # define a slave to search by `editor` only
    add_slave 'Book_by_editor' do
      attributesToIndex [:editor]
    end
  end

end
```

Advanced indexing
---------

You can index a record in several indexes using the <code>add_index</code> method.

```ruby
class Book < ActiveRecord::Base
  attr_protected

  include AlgoliaSearch

  PUBLIC_INDEX_NAME  = "Book_#{Rails.env}"
  SECURED_INDEX_NAME = "SecuredBook_#{Rails.env}"

  # store all books in index 'SECURED_INDEX_NAME' 
  algoliasearch index_name: SECURED_INDEX_NAME do
    attributesToIndex [:name, :author]
    # convert security to tags
    tags do
      [released ? 'public' : 'private', premium ? 'premium' : 'standard']
    end

    # store all 'public' (released and not premium) books in index 'PUBLIC_INDEX_NAME'
    add_index PUBLIC_INDEX_NAME, if: :public? do
      attributesToIndex [:name, :author]
    end
  end

  private
  def public?
    released && !premium
  end

end
```

Tags
-----

Use the <code>tags</code> method to add tags to your record:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    tags ['trusted']
  end
end
```

or using dynamical values:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    tags do
      [first_name.blank? || last_name.blank? ? 'partial' : 'full', has_valid_email? ? 'valid_email' : 'invalid_email']
    end
  end
end
```

At query time, specify <code>{ tagFilters: 'tagvalue' }</code> or <code>{ tagFilters: ['tagvalue1', 'tagvalue2'] }</code> as search parameters to restrict the result set to specific tags.

Search
----------

A search returns ORM-compliant objects reloading them from your database. We recommend the usage of our [JavaScript API Client](https://github.com/algolia/algoliasearch-client-js) to perform queries to decrease the overall latency and offload your servers.


```ruby
hits =  Contact.search("jon doe")
p hits
p hits.raw_answer # to get the original JSON raw answer
```

If you want to retrieve the raw JSON answer from the API, without re-loading the objects from the database, you can use:

```ruby
json_answer = Contact.raw_search("jon doe")
p json_answer
p json_answer['hits']
p json_answer['facets']
```

Search parameters can be specified either through the index's [settings](https://github.com/algolia/algoliasearch-client-ruby#index-settings) statically in your model or dynamically at search time specifying [search parameters](https://github.com/algolia/algoliasearch-client-ruby#search) as second argument of the ```search``` method:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    attribute :first_name, :last_name, :email
    
    # default search parameters stored in the index settings
    minWordSizeForApprox1 4
    minWordSizeForApprox2 8
    hitsPerPage 42
  end
end
```

```ruby
# dynamical search parameters
p Contact.search("jon doe", { :hitsPerPage => 5, :page => 2 })
```

Faceting
---------

Facets can be retrieved calling the extra ```facets``` method of the search answer.

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    # [...]

    # specify the list of attributes available for faceting
    attributesForFaceting [:company, :zip_code]
  end
end
```

```ruby
hits = Contact.search("jon doe", { :facets => '*' })
p hits                    # ORM-compliant array of objects
p hits.facets             # extra method added to retrieve facets
p hits.facets['company']  # facet values+count of facet 'company'
p hits.facets['zip_code'] # facet values+count of facet 'zip_code'
```

```ruby
raw_json = Contact.raw_search("jon doe", { :facets => '*' })
p raw_json['facets']
```

Geo-Search
-----------

Use the <code>geoloc</code> method to localize your record:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    geoloc :lat_attr, :lng_attr
  end
end
```

At query time, specify <code>{ aroundLatLng: "37.33, -121.89", aroundRadius: 50000 }</code> as search parameters to restrict the result set to 50KM around San Jose.

Typeahead UI
-------------

Require ```algolia/algoliasearch.min``` (see [algoliasearch-client-js](https://github.com/algolia/algoliasearch-client-js)) and ```algolia/typeahead.jquery.js``` somewhere in your JavaScript manifest, for example in ```application.js``` if you are using Rails 3.1+:

```javascript
//= require algolia/algoliasearch.min
//= require algolia/typeahead.jquery
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
    var client = new AlgoliaSearch('YourApplicationID', 'SearchOnlyApplicationKey');
    var template = Hogan.compile('{{{_highlightResult.email.value}}} ({{{_highlightResult.first_name.value}}} {{{_highlightResult.last_name.value}}})');
    $('input#user_email').typeahead(null, {
      source: client.initIndex('<%= Contact.index_name %>').ttAdapter(),
      displayKey: 'email',
      templates: {
        suggestion: function(hit) {
          return template.render(hit);
        }
      }
    });
  });
</script>
```


Note on testing
-----------------

To run the specs, please set the <code>ALGOLIA_APPLICATION_ID</code> and <code>ALGOLIA_API_KEY</code> environment variables. Since the tests are creating and removing indexes, DO NOT use your production account.
