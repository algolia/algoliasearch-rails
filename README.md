Algolia Search for Rails
==================

This gem let you easily integrate the Algolia Search API to your favorite ORM. It's based on the [algoliasearch-client-ruby](https://github.com/algolia/algoliasearch-client-ruby) gem. Both Rails 3.x and Rails 4.x are supported.

You might be interested in the sample Ruby on Rails application providing a ```typeahead.js```-based auto-completion and ```Google```-like instant search: [algoliasearch-rails-example](https://github.com/algolia/algoliasearch-rails-example/).

[![Build Status](https://travis-ci.org/algolia/algoliasearch-rails.png?branch=master)](https://travis-ci.org/algolia/algoliasearch-rails) [![Gem Version](https://badge.fury.io/rb/algoliasearch-rails.png)](http://badge.fury.io/rb/algoliasearch-rails) [![Code Climate](https://codeclimate.com/github/algolia/algoliasearch-rails.png)](https://codeclimate.com/github/algolia/algoliasearch-rails) ![ActiveRecord](https://img.shields.io/badge/ActiveRecord-yes-blue.svg?style=flat-square) ![Mongoid](https://img.shields.io/badge/Mongoid-yes-blue.svg?style=flat-square) ![Sequel](https://img.shields.io/badge/Sequel-yes-blue.svg?style=flat-square)

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
1. [Share a single index](#share-a-single-index)
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

The gem is compatible with [ActiveRecord](https://github.com/rails/rails/tree/master/activerecord), [Mongoid](https://github.com/mongoid/mongoid) and [Sequel](https://github.com/jeremyevans/sequel).

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

    # the attributesToIndex` setting defines the attributes
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

The JS API client is part of the gem, just require ```algolia/v3/algoliasearch.min``` somewhere in your JavaScript manifest, for example in ```application.js``` if you are using Rails 3.1+:

```javascript
//= require algolia/v3/algoliasearch.min
```

Then in your JavaScript code you can do:

```js
var client = algoliasearch(ApplicationID, Search-Only-API-Key);
var index = client.initIndex('YourIndexName');
index.search('something', function(success, hits) {
  console.log(success, hits)
}, { hitsPerPage: 10, page: 0 });
```

**We recently (March 2015) released a new version (V3) of our JavaScript client, if you were using our previous version (V2), [read the migration guide](https://github.com/algolia/algoliasearch-client-js/wiki/Migration-guide-from-2.x.x-to-3.x.x)**

#### Backend Search

If you want to search from your backend you can use the `raw_search` method. It retrieves the raw JSON answer from the API:

```ruby
p Contact.raw_search("jon doe")
```

You could also use `search` but it's not recommended. This method will fetch the matching `objectIDs` from the API and perform a database query to retrieve an array of matching models:

```ruby
p Contact.search("jon doe") # we recommend to use `raw_search` to avoid the database lookup
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

Each time a record is saved; it will be - asynchronously - indexed. On the other hand, each time a record is destroyed, it will be - asynchronously - removed from the index. That means that a network call with the ADD/DELETE operation is sent **synchronously** to the Algolia API but then the engine will **asynchronously** process the operation (so if you do a search just after, the results may not reflect it yet).

You can disable auto-indexing and auto-removing setting the following options:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch auto_index: false, auto_remove: false do
    attribute :first_name, :last_name, :email
  end
end
```

##### Temporary disable auto-indexing

You can temporary disable auto-indexing using the <code>without_auto_index</code> scope. This is often used for performance reason.

```ruby
Contact.delete_all
Contact.without_auto_index do
  1.upto(10000) { Contact.create! attributes } # inside this block, auto indexing task will not run.
end
Contact.reindex! # will use batch operations
```

##### Queues & background jobs

You can configure the auto-indexing & auto-removal process to use a queue to perform those operations in background. ActiveJob (Rails >=4.2) queues are used by default but you can define your own queuing mechanism:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch enqueue: true do # ActiveJob will be triggered using a `algoliasearch` queue
    attribute :first_name, :last_name, :email
  end
end
```

##### Things to Consider

If you are performing updates & deletions in the background then a record deletion can be committed to your database prior
to the job actually executing. Thus if you were to load the record to remove it from the database than your ActiveRecord#find will fail with a RecordNotFound. 

In this case you can bypass loading the record from ActiveRecord and just communicate with the index directly:

```ruby
class MySidekiqWorker
  def perform(id, remove)
    if remove
      # the record has likely already been removed from your database so we cannot
      # use ActiveRecord#find to load it
      index = Algolia::Index.new("index_name")
      index.delete_object(id)
    else
      # the record should be present
      c = Contact.find(id)
      c.index!
    end
  end
end
```

##### With Sidekiq

If you're using [Sidekiq](https://github.com/mperham/sidekiq):

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch enqueue: :trigger_sidekiq_worker do
    attribute :first_name, :last_name, :email
  end

  def self.trigger_sidekiq_worker(record, remove)
    MySidekiqWorker.perform_async(record.id, remove)
  end
end

class MySidekiqWorker
  def perform(id, remove)
    c = Contact.find(id)
    remove ? c.remove_from_index! : c.index!
  end
end
```

##### With DelayedJob

If you're using [delayed_job](https://github.com/collectiveidea/delayed_job):

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch enqueue: :trigger_delayed_job do
    attribute :first_name, :last_name, :email
  end

  def self.trigger_delayed_job(record, remove)
    if remove
      record.delay.remove_from_index!
    else
      record.delay.index!
    end
  end
end

```

##### Synchronism & testing

You can force indexing and removing to be synchronous (in that case the gem will call the `wait_task` method to ensure the operation has been taken into account once the method returns) by setting the following option: (this is **NOT** recommended, except for testing purpose)

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch synchronous: true do
    attribute :first_name, :last_name, :email
  end
end
```

#### Exceptions

You can disable exceptions that could be raised while trying to reach Algolia's API by using the `raise_on_failure` option:

```ruby
class Contact < ActiveRecord::Base
  include AlgoliaSearch

  # only raise exceptions in development env
  algoliasearch raise_on_failure: Rails.env.development? do
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

It allows you to do conditional indexing on a per document basis. 

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
    attributesToIndex ['unordered(title)', 'unordered(story_text)', 'unordered(comment_text)', 'unordered(url)', 'author']

    # tags used for filtering
    tags do
      [item_type, "author_#{author}", "story_#{story_id}"]
    end

    # use associated number of HN points to sort results (last sort criteria)
    customRanking ['desc(points)', 'desc(num_comments)']

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

#### Using the underlying index

You can access the underlying `index` object by calling the `index` class method:

```ruby
index = Contact.index
# index.get_settings, index.partial_update_object, ...
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

Share a single index
---------

It can make sense to share an index between several models. In order to implement that, you'll need to ensure you don't have any conflict with the `objectID` of the underlying models.

```ruby
class Student < ActiveRecord::Base
  attr_protected

  include AlgoliaSearch

  algoliasearch index_name: 'people', id: :algolia_id do
    # [...]
  end

  private
  def algolia_id
    "student_#{id}" # ensure the teacher & student IDs are not conflicting
  end
end

class Teacher < ActiveRecord::Base
  attr_protected

  include AlgoliaSearch

  algoliasearch index_name: 'people', id: :algolia_id do
    # [...]
  end

  private
  def algolia_id
    "teacher_#{id}" # ensure the teacher & student IDs are not conflicting
  end
end
```

***Notes:*** If you target a single index from several models, you must never use `MyModel.reindex` and only use `MyModel.reindex!`. The `reindex` method uses a temporary index to perform an atomic reindexing: if you use it, the resulting index will only contain records for the current model because it will not reindex the others.

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
p Contact.raw_search("jon doe", { :hitsPerPage => 5, :page => 2 })
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

Require ```algolia/v3/algoliasearch.min``` (see [algoliasearch-client-js](https://github.com/algolia/algoliasearch-client-js)) and ```algolia/typeahead.jquery.js``` somewhere in your JavaScript manifest, for example in ```application.js``` if you are using Rails 3.1+:

```javascript
//= require algolia/v3/algoliasearch.min
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
    var client = algoliasearch('YourApplicationID', 'SearchOnlyApplicationKey');
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

This gem makes intensive use of Rails' callbacks to trigger the indexing tasks. If you're using methods bypassing ```after_validation```, ```before_save``` or ```after_commit``` callbacks, it will not index your changes. For example: ```update_attribute``` doesn't perform validations checks, to perform validations when updating use ```update_attributes```.

Timeouts
---------

You can configure a bunch of timeout threshold by setting the following options at initialization time:

```ruby
AlgoliaSearch.configuration = {
  application_id: 'YourApplicationID',
  api_key: 'YourAPIKey'
  connect_timeout: 2,
  receive_timeout: 30,
  send_timeout: 30,
  batch_timeout: 120,
  search_timeout: 5
}
```

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
