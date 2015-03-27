Algolia Search for Rails
==================

This gem let you easily integrate the Algolia Search API to your favorite ORM. It's based on the [algoliasearch-client-ruby](https://github.com/algolia/algoliasearch-client-ruby) gem. Both Rails 3.x and Rails 4.x are supported.

You might be interested in the sample Ruby on Rails application providing a ```typeahead.js```-based auto-completion and ```Google```-like instant search: [algoliasearch-rails-example](https://github.com/algolia/algoliasearch-rails-example/).

[![Build Status](https://travis-ci.org/algolia/algoliasearch-rails.png?branch=master)](https://travis-ci.org/algolia/algoliasearch-rails) [![Gem Version](https://badge.fury.io/rb/algoliasearch-rails.png)](http://badge.fury.io/rb/algoliasearch-rails) [![Code Climate](https://codeclimate.com/github/algolia/algoliasearch-rails.png)](https://codeclimate.com/github/algolia/algoliasearch-rails)

Table of Content
-------------
**Get started**

1. [Install](#install)
1. [Setup](#setup)
1. [Quick Start](#quick-start)
1. [Ranking & Relevance](#ranking--relevance)
1. [Options](#options)
1. [Configuration example](#configuration-example)
1. [Indexing](#indexing)
1. [Master/Slave](#masterslave)
1. [Target multiple indexes](#target-multiple-indexes)
1. [Tags](#tags)
1. [Search](#search)
1. [Faceting](#faceting)
1. [Geo-search](#geo-search)
1. [Typeahead UI](#typeahead-ui)
1. [Caveats](#caveats)
1. [Note on testing](#note-on-testing)

Install
-------------

```sh
gem install algoliasearch-rails
```

Add the gem to your <code>Gemfile</code>:

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

#### Ranking & Relevance

We provide many ways to configure your index allowing you to tune your overall index relevancy. The most important ones are the **searchable attributes** and the attributes reflecting **record popularity**.

```ruby
class Product < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    # list of attribute used to build an Algolia record
    attributes :title, :subtitle, :description, :likes_count, :seller_name

    # the attributesToIndex` setting desfined the attributes
    # you want to search in: here `title`, `subtitle` & `description`.
    # You need to list them by order of importance. `description` is tagged as
    # `unordered` to avoid taking the position of a match into account in that attribute.
    attributesToIndex ['title', 'subtitle', 'unordered(description)']

    # the `customRanking` setting defines the ranking criteria use to compare two matching
    # records in case their text-relevance is equal. It should reflect your record popularity.
    customRanking ['desc(likes_count)']
  end

end
```

#### Frontend Search (realtime experience)

Traditional search implementations tend to have search logic and functionality on the backend. This made sense when the search experience consisted of a user entering a search query, executing that search, and then being redirected to a search result page.

Implementing search on the backend is no longer necessary. In fact, in most cases it is harmful to performance because of added network and processing latency. We highly recommend the usage of our [JavaScript API Client](https://github.com/algolia/algoliasearch-client-js) issuing all search requests directly from the end user's browser, mobile device, or client. It will reduce the overall search latency while offloading your servers at the same time.

The JS API client is part of the gem, just require ```algolia/algoliasearch.min``` somewhere in your JavaScript manifest, for example in ```application.js``` if you are using Rails 3.1+:

```javascript
//= require algolia/algoliasearch.min
```

Then in your JavaScript code you can do:

```js
var client = new AlgoliaSearch('ApplicationID', 'Search-Only-API-Key');
var index = client.initIndex('YourIndexName');
index.search('something', function(success, hits) {
  console.log(success, hits)
}, { hitsPerPage: 10, page: 0 });
```

#### Backend Search

A search returns ORM-compliant objects reloading them from your database.

```ruby
p Contact.search("jon doe")
```

If you want to retrieve the raw JSON answer from the API, without re-loading the objects from the database, you can use:

```ruby
p Contact.raw_search("jon doe")
```

#### Notes

All methods injected by the ```AlgoliaSearch``` include are prefixed by ```algolia_``` and aliased to the associated short names if they aren't already defined.

```ruby
Contact.algolia_reindex! # <=> Contact.reindex!

Contact.algolia_search("jon doe") # <=> Contact.search("jon doe")
```

Options
----------

#### Auto-indexing & asynchronism

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
  1.upto(10000) { Contact.create! attributes } # inside this block, auto indexing task will not run.
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

#### Custom index name

By default, the index name will be the class name, e.g. "Contact". You can customize the index name by using the `index_name` option:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch index_name: "MyCustomName" do
    attribute :first_name, :last_name, :email
  end
end
```

#### Per-environment indexes

You can suffix the index name with the current Rails environment using the following option:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch per_environment: true do # index name will be "Contact_#{Rails.env}"
    attribute :first_name, :last_name, :email
  end
end
```

#### Custom attribute definition

You can use a block to specify a complex attribute value

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    attribute :email
    attribute :full_name do
      "#{first_name} #{last_name}"
    end
    add_attribute :full_name2
  end

  def full_name2
    "#{first_name} #{last_name}"
  end
end
```

***Notes:*** As soon as you use such code to define extra attributes, the gem is not anymore able to detect if the attribute has changed (the code uses Rails's `#{attribute}_changed?` method to detect that). As a consequence, your record will be pushed to the API even if its attributes didn't change. You can work-around this behavior creating a `_changed?` method:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
    attribute :email
    attribute :full_name do
      "#{first_name} #{last_name}"
    end
  end

  def full_name_changed?
    first_name_changed? || last_name_changed?
  end
end
```

#### Nested objects/relations

You can easily embed nested objects defining an extra attribute returning any JSON-compliant object (an array or a hash or a combination of both).

```ruby
class Profile < ActiveRecord::Base
  include AlgoliaSearch

  belongs_to :user
  has_many :specializations

  algoliasearch do
    attribute :user do
      # restrict the nested "user" object to its `name` + `email`
      { name: user.name, email: user.email }
    end
    attribute :public_specializations do
      # build an array of public specialization (include only `title` and `another_attr`)
      specializations.select { |s| s.public? }.map do |s|
        { title: s.title, another_attr: s.another_attr }
      end
    end
  end

end
```

#### Custom ```objectID```

By default, the `objectID` is based on your record's `id`. You can change this behavior specifying the `:id` option (be sure to use a uniq field).

```ruby
class UniqUser < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch id: :uniq_name do
  end
end
```

#### Restrict indexing to a subset of your data

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

**Notes:** As soon as you use those constraints, ```addObjects``` and ```deleteObjects``` calls will be performed in order to keep the index synced with the DB (The state-less gem doesn't know if the object don't match your constraints anymore or never matched, so we force ADD/DELETE operations to be sent). You can work-around this behavior creating a `_changed?` method:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch if: :published do
  end

  def published
    # true or false
  end

  def published_changed?
    # return true only if you know that the 'published' state changed
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

#### Sanitizer

You can sanitize all your attributes using the ```sanitize``` option. It will strip all HTML tags from your attributes.

```ruby
class User < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch per_environment: true, sanitize: true do
    attributes :name, :email, :company
  end
end

```

If you're using Rails 4.2+, you also need to depend on `rails-html-sanitizer`:

```ruby
gem 'rails-html-sanitizer'
```


#### UTF-8 Encoding

You can force the UTF-8 encoding of all your attributes using the ```force_utf8_encoding``` option:

```ruby
class User < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch force_utf8_encoding: true do
    attributes :name, :email, :company
  end
end

```

***Notes:*** This option is not compatible with Ruby 1.8


Configuration example
---------------------

Here is a real-word configuration example (from [HN Search](https://github.com/algolia/hn-search)):

```ruby
class Item < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch per_environment: true do
    # the list of attributes sent to Algolia's API
    attribute :created_at, :title, :url, :author, :points, :story_text, :comment_text, :author, :num_comments, :story_id, :story_title

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

#### Manual indexing

You can trigger indexing using the <code>index!</code> instance method.

```ruby
c = Contact.create!(params[:contact])
c.index!
```

#### Manual removal

And trigger index removing using the <code>remove_from_index!</code> instance method.

```ruby
c.remove_from_index!
c.destroy
```

#### Reindexing

To *safely* reindex all your records (index to a temporary index + move the temporary index to the current one atomically), use the <code>reindex</code> class method:

```ruby
Contact.reindex
```

To reindex all your records (in place, without deleting out-dated records), use the <code>reindex!</code> class method:

```ruby
Contact.reindex!
```

#### Clearing an index

To clear an index, use the <code>clear_index!</code> class method:

```ruby
Contact.clear_index!
```

Master/slave
---------

You can define slave indexes using the <code>add_slave</code> method:

```ruby
class Book < ActiveRecord::Base
  attr_protected

  include AlgoliaSearch

  algoliasearch per_environment: true do
    attributesToIndex [:name, :author, :editor]

    # define a slave index to search by `author` only
    add_slave 'Book_by_author', per_environment: true do
      attributesToIndex [:author]
    end

    # define a slave index to search by `editor` only
    add_slave 'Book_by_editor', per_environment: true do
      attributesToIndex [:editor]
    end
  end

end
```

To search using a slave, use the following code:

```ruby
Book.raw_search 'foo bar', slave: 'Book_by_editor'
# or
Book.search 'foo bar', slave: 'Book_by_editor'
```

Target multiple indexes
---------

You can index a record in several indexes using the <code>add_index</code> method:

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

To search using an extra index, use the following code:

```ruby
Book.raw_search 'foo bar', index: 'Book_by_editor'
# or
Book.search 'foo bar', index: 'Book_by_editor'
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

***Notes:*** We recommend the usage of our [JavaScript API Client](https://github.com/algolia/algoliasearch-client-js) to perform queries directly from the end-user browser without going through your server.

A search returns ORM-compliant objects reloading them from your database. We recommend the usage of our [JavaScript API Client](https://github.com/algolia/algoliasearch-client-js) to perform queries to decrease the overall latency and offload your servers.


```ruby
hits =  Contact.search("jon doe")
p hits
p hits.raw_answer # to get the original JSON raw answer
```

A `highlight_result` attribute is added to each ORM object:

```ruby
hits[0].highlight_result['first_name']['value']
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

Caveats
--------

This gem makes intensive use of Rails' callbacks to trigger the indexing tasks. If you're using methods bypassing ```after_validation```, ```before_save``` or ```after_save``` callbacks, it will not index your changes. For example: ```update_attribute``` doesn't perform validations checks, to perform validations when updating use ```update_attributes```.

Note on testing
-----------------

To run the specs, please set the <code>ALGOLIA_APPLICATION_ID</code> and <code>ALGOLIA_API_KEY</code> environment variables. Since the tests are creating and removing indexes, DO NOT use your production account.

You may want to disable all indexing (add, update & delete operations) API calls, you can set the ```disable_indexing``` option:

```ruby
class User < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :per_environment => true, :disable_indexing => Rails.env.test? do
  end
end

class User < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :per_environment => true, :disable_indexing => Proc.new { Rails.env.test? || more_complex_condition } do
  end
end
```

Or you may want to mock Algolia's API calls. We provide a [WebMock](https://github.com/bblimke/webmock) sample configuration that you can use including `algolia/webmock`:

```ruby
require 'algolia/webmock'

describe 'With a mocked client' do

  before(:each) do
    WebMock.enable!
  end

  it "shouldn't perform any API calls here" do
    User.create(name: 'My Indexed User')  # mocked, no API call performed
    User.search('').should == {}          # mocked, no API call performed
  end

  after(:each) do
    WebMock.disable!
  end

end
```
