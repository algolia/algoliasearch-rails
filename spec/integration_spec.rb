require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

OLD_RAILS = Gem.loaded_specs['rails'].version < Gem::Version.new('4.0')
NEW_RAILS = Gem.loaded_specs['rails'].version >= Gem::Version.new('6.0')

require 'active_record'
unless OLD_RAILS || NEW_RAILS
  require 'active_job/test_helper'
  ActiveJob::Base.queue_adapter = :test
end
require 'sqlite3' if !defined?(JRUBY_VERSION)
require 'logger'
require 'sequel'
require 'active_model_serializers'

AlgoliaSearch.configuration = { :application_id => ENV['ALGOLIA_APPLICATION_ID'], :api_key => ENV['ALGOLIA_API_KEY'], :use_latest_settings => false, :symbolize_keys => false }

FileUtils.rm( 'data.sqlite3' ) rescue nil
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::WARN
ActiveRecord::Base.establish_connection(
    'adapter' => defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3',
    'database' => 'data.sqlite3',
    'pool' => 5,
    'timeout' => 5000
)

if ActiveRecord::Base.respond_to?(:raise_in_transactional_callbacks)
  ActiveRecord::Base.raise_in_transactional_callbacks = true
end

SEQUEL_DB = Sequel.connect(defined?(JRUBY_VERSION) ? 'jdbc:sqlite:sequel_data.sqlite3' : { 'adapter' => 'sqlite', 'database' => 'sequel_data.sqlite3' })

unless SEQUEL_DB.table_exists?(:sequel_books)
  SEQUEL_DB.create_table(:sequel_books) do
    primary_key :id
    String :name
    String :author
    FalseClass :released
    FalseClass :premium
  end
end

ActiveRecord::Schema.define do
  create_table :products do |t|
    t.string :name
    t.string :href
    t.string :tags
    t.string :type
    t.text :description
    t.datetime :release_date
  end
  create_table :colors do |t|
    t.string :name
    t.string :short_name
    t.integer :hex
  end
  create_table :namespaced_models do |t|
    t.string :name
    t.integer :another_private_value
  end
  create_table :uniq_users, :id => false do |t|
    t.string :name
  end
  create_table :nullable_ids do |t|
  end
  create_table :nested_items do |t|
    t.integer :parent_id
    t.boolean :hidden
  end
  create_table :cities do |t|
    t.string :name
    t.string :country
    t.float :lat
    t.float :lng
    t.string :gl_array
  end
  create_table :with_slaves do |t|
  end
  create_table :mongo_objects do |t|
    t.string :name
  end
  create_table :books do |t|
    t.string :name
    t.string :author
    t.boolean :premium
    t.boolean :released
  end
  create_table :ebooks do |t|
    t.string :name
    t.string :author
    t.boolean :premium
    t.boolean :released
  end
  create_table :disabled_booleans do |t|
    t.string :name
  end
  create_table :disabled_procs do |t|
    t.string :name
  end
  create_table :disabled_symbols do |t|
    t.string :name
  end
  create_table :encoded_strings do |t|
  end
  create_table :forward_to_replicas do |t|
    t.string :name
  end
  create_table :forward_to_replicas_twos do |t|
    t.string :name
  end
  create_table :sub_replicas do |t|
    t.string :name
  end
  unless OLD_RAILS
    create_table :enqueued_objects do |t|
      t.string :name
    end
    create_table :disabled_enqueued_objects do |t|
      t.string :name
    end
  end
  create_table :misconfigured_blocks do |t|
    t.string :name
  end
  if defined?(ActiveModel::Serializer)
    create_table :serialized_objects do |t|
      t.string :name
      t.string :skip
    end
  end
end

class Product < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :auto_index => false,
    :if => :published?, :unless => lambda { |o| o.href.blank? },
    :index_name => safe_index_name("my_products_index") do

    attribute :href, :name, :tags
    tags do
      [name, name] # multiple tags
    end

    synonyms [
      ['iphone', 'applephone', 'iBidule'],
      ['apple', 'pomme'],
      ['samsung', 'galaxy']
    ]
  end

  def tags=(names)
    @tags = names.join(",")
  end

  def published?
    release_date.blank? || release_date <= Time.now
  end
end

class Camera < Product
end

class Color < ActiveRecord::Base
  include AlgoliaSearch
  attr_accessor :not_indexed

  algoliasearch :synchronous => true, :index_name => safe_index_name("Color"), :per_environment => true do
    attributesToIndex [:name]
    attributesForFaceting ['searchable(short_name)']
    customRanking ["asc(hex)"]
    tags do
      name # single tag
    end

    # we're using all attributes of the Color class + the _tag "extra" attribute
  end

  def hex_changed?
    false
  end

  def will_save_change_to_short_name?
    false
  end

  def will_save_change_to__tags?
    false
  end
end

class DisabledBoolean < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :synchronous => true, :disable_indexing => true, :index_name => safe_index_name("DisabledBoolean") do
  end
end

class DisabledProc < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :synchronous => true, :disable_indexing => Proc.new { true }, :index_name => safe_index_name("DisabledProc") do
  end
end

class DisabledSymbol < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :synchronous => true, :disable_indexing => :truth, :index_name => safe_index_name("DisabledSymbol") do
  end

  def self.truth
    true
  end
end

module Namespaced
  def self.table_name_prefix
    'namespaced_'
  end
end
class Namespaced::Model < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :synchronous => true, :index_name => safe_index_name(algolia_index_name({})) do
    attribute :customAttr do
      40 + another_private_value
    end
    attribute :myid do
      id
    end
    searchableAttributes ['customAttr']
    tags ['static_tag1', 'static_tag2']
  end
end

class UniqUser < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :synchronous => true, :index_name => safe_index_name("UniqUser"), :per_environment => true, :id => :name do
  end
end

class NullableId < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :synchronous => true, :index_name => safe_index_name("NullableId"), :per_environment => true, :id => :custom_id, :if => :never do
  end

  def custom_id
    nil
  end

  def never
    false
  end
end

class NestedItem < ActiveRecord::Base
  has_many :children, :class_name => "NestedItem", :foreign_key => "parent_id"

  include AlgoliaSearch

  algoliasearch :synchronous => true, :index_name => safe_index_name("NestedItem"), :per_environment => true, :unless => :hidden do
    attribute :nb_children
  end

  def nb_children
    children.count
  end
end

# create this index before the class actually loads, to ensure the customRanking is updated
index = AlgoliaSearch.client.init_index(safe_index_name('City_replica2'))
index.set_settings!({'customRanking' => ['desc(d)']})

class City < ActiveRecord::Base
  include AlgoliaSearch

  serialize :gl_array

  def geoloc_array
    lat.present? && lng.present? ? { :lat => lat, :lng => lng } : gl_array
  end

  algoliasearch :synchronous => true, :index_name => safe_index_name("City"), :per_environment => true do
    geoloc do
      geoloc_array
    end
    add_attribute :a_null_lat, :a_lng
    customRanking ['desc(b)']

    add_replica safe_index_name('City_replica1'), :per_environment => true do
      attributesToIndex [:country]
      customRanking ['asc(a)']
    end

    add_replica safe_index_name('City_replica2'), :per_environment => true do
      customRanking ['asc(a)', 'desc(c)']
    end
  end

  def a_null_lat
    nil
  end

  def a_lng
    1.2345678
  end
end

class SequelBook < Sequel::Model(SEQUEL_DB)
  plugin :active_model

  include AlgoliaSearch

  algoliasearch :synchronous => true, :index_name => safe_index_name("SequelBook"), :per_environment => true, :sanitize => true do
    add_attribute :test
    add_attribute :test2

    attributesToIndex [:name]
  end

  def after_create
    SequelBook.new
  end

  def test
    'test'
  end

  def test2
    'test2'
  end

  private
  def public?
    released && !premium
  end
end

describe 'SequelBook' do
  before(:all) do
    SequelBook.clear_index!(true)
  end

  it "should index the book" do
    @steve_jobs = SequelBook.create :name => 'Steve Jobs', :author => 'Walter Isaacson', :premium => true, :released => true
    results = SequelBook.search('steve')
    expect(results.size).to eq(1)
    expect(results[0].id).to eq(@steve_jobs.id)
  end

  it "should not override after hooks" do
    expect(SequelBook).to receive(:new).twice.and_call_original
    SequelBook.create :name => 'Steve Jobs', :author => 'Walter Isaacson', :premium => true, :released => true
  end

end

class MongoObject < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :index_name => safe_index_name("MongoObject") do
  end

  def self.reindex!
    raise NameError.new("never reached")
  end

  def index!
    raise NameError.new("never reached")
  end
end

class Book < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :synchronous => true, :index_name => safe_index_name("SecuredBook"), :per_environment => true, :sanitize => true do
    attributesToIndex [:name]
    tags do
      [premium ? 'premium' : 'standard', released ? 'public' : 'private']
    end

    add_index safe_index_name('BookAuthor'), :per_environment => true do
      attributesToIndex [:author]
    end

    add_index safe_index_name('Book'), :per_environment => true, :if => :public? do
      attributesToIndex [:name]
    end
  end

  private
  def public?
    released && !premium
  end
end

class Ebook < ActiveRecord::Base
  include AlgoliaSearch
  attr_accessor :current_time, :published_at

  algoliasearch :synchronous => true, :index_name => safe_index_name("eBooks")do
    attributesToIndex [:name]
  end

  def algolia_dirty?
    return true if self.published_at.nil? || self.current_time.nil?
    # Consider dirty if published date is in the past
    # This doesn't make so much business sense but it's easy to test.
    self.published_at < self.current_time
  end
end

class EncodedString < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :synchronous => true, :force_utf8_encoding => true, :index_name => safe_index_name("EncodedString") do
    attribute :value do
      "\xC2\xA0\xE2\x80\xA2\xC2\xA0".force_encoding('ascii-8bit')
    end
  end
end

class SubReplicas < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :synchronous => true, :force_utf8_encoding => true, :index_name => safe_index_name("SubReplicas") do
    attributesToIndex [:name]
    customRanking ["asc(name)"]

    add_index safe_index_name("Additional_Index"), :per_environment => true do
      attributesToIndex [:name]
      customRanking ["asc(name)"]

      add_replica safe_index_name("Replica_Index"), :per_environment => true do
        attributesToIndex [:name]
        customRanking ["desc(name)"]
      end
    end
  end
end

class WithSlave < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :force_utf8_encoding => true, :index_name => safe_index_name("WithSlave") do
    add_slave safe_index_name("WithSlave_slave") do
    end
  end

  # Ensure the index is indeed using slaves
  algolia_index.set_settings!({:slaves => [safe_index_name("WithSlave_slave")]})
end

unless OLD_RAILS
  class EnqueuedObject < ActiveRecord::Base
    include AlgoliaSearch

    include GlobalID::Identification

    def id
      read_attribute(:id)
    end

    def self.find(id)
      EnqueuedObject.first
    end

    algoliasearch :enqueue => Proc.new { |record| raise "enqueued #{record.id}" },
      :index_name => safe_index_name('EnqueuedObject') do
      attributes [:name]
    end
  end

  class DisabledEnqueuedObject < ActiveRecord::Base
    include AlgoliaSearch

    algoliasearch(:enqueue => Proc.new { |record| raise "enqueued" },
      :index_name => safe_index_name('EnqueuedObject'),
      :disable_indexing => true) do
      attributes [:name]
    end
  end
end

class MisconfiguredBlock < ActiveRecord::Base
  include AlgoliaSearch
end

if defined?(ActiveModel::Serializer)
  class SerializedObjectSerializer < ActiveModel::Serializer
    attributes :name
  end

  class SerializedObject < ActiveRecord::Base
    include AlgoliaSearch

    algoliasearch :index_name => safe_index_name('SerializedObject') do
      use_serializer SerializedObjectSerializer

      tags do
        ['tag1', 'tag2']
      end
    end
  end
end

if defined?(ActiveModel::Serializer)
  describe 'SerializedObject' do
    before(:all) do
      SerializedObject.clear_index!(true)
    end

    it "should push the name but not the other attribute" do
      o = SerializedObject.new :name => 'test', :skip => 'skip me'
      attributes = SerializedObject.algoliasearch_settings.get_attributes(o)
      expect(attributes).to eq({:name => 'test', "_tags" => ['tag1', 'tag2']})
    end
  end
end

describe 'Encoding' do
  before(:all) do
    EncodedString.clear_index!(true)
  end

  if Object.const_defined?(:RUBY_VERSION) && RUBY_VERSION.to_f > 1.8
    it "should convert to utf-8" do
      EncodedString.create!
      results = EncodedString.raw_search ''
      expect(results['hits'].size).to eq(1)
      expect(results['hits'].first['value']).to eq("\xC2\xA0\xE2\x80\xA2\xC2\xA0".force_encoding('utf-8'))
    end
  end
end

# Rails 3.2 swallows exception in after_commit
unless OLD_RAILS
  describe 'Too big records' do
    before(:all) do
      Color.clear_index!(true)
    end

    after(:all) do
      Color.delete_all
    end

    it "should throw an exception if the data is too big" do
      expect {
        Color.create! :name => 'big' * 100000
      }.to raise_error(Algolia::AlgoliaHttpError)
    end

  end
end

describe 'Settings' do

  it "should detect settings changes" do
    Color.send(:algoliasearch_settings_changed?, nil, {}).should == true
    Color.send(:algoliasearch_settings_changed?, {}, {"attributesToIndex" => ["name"]}).should == true
    Color.send(:algoliasearch_settings_changed?, {"attributesToIndex" => ["name"]}, {"attributesToIndex" => ["name", "hex"]}).should == true
    Color.send(:algoliasearch_settings_changed?, {"attributesToIndex" => ["name"]}, {"customRanking" => ["asc(hex)"]}).should == true
  end

  it "should not detect settings changes" do
    Color.send(:algoliasearch_settings_changed?, {}, {}).should == false
    Color.send(:algoliasearch_settings_changed?, {"attributesToIndex" => ["name"]}, {:attributesToIndex => ["name"]}).should == false
    Color.send(:algoliasearch_settings_changed?, {"attributesToIndex" => ["name"], "customRanking" => ["asc(hex)"]}, {"customRanking" => ["asc(hex)"]}).should == false
  end

end

describe 'Change detection' do

  it "should detect attribute changes" do
    color = Color.new :name => "dark-blue", :short_name => "blue"

    Color.algolia_must_reindex?(color).should == true
    color.save
    Color.algolia_must_reindex?(color).should == false

    color.hex = 123456
    Color.algolia_must_reindex?(color).should == false

    color.not_indexed = "strstr"
    Color.algolia_must_reindex?(color).should == false
    color.name = "red"
    Color.algolia_must_reindex?(color).should == true

    color.delete
  end

  it "should detect attribute changes even in a transaction" do
    color = Color.new :name => "dark-blue", :short_name => "blue"
    color.save

    color.instance_variable_get("@algolia_must_reindex").should == nil
    Color.transaction do
      color.name = "red"
      color.save
      color.not_indexed = "strstr"
      color.save
      color.instance_variable_get("@algolia_must_reindex").should == true
    end
    color.instance_variable_get("@algolia_must_reindex").should == nil

    color.delete
  end

  it "should detect change with algolia_dirty? method" do
    ebook = Ebook.new :name => "My life", :author => "Myself", :premium => false, :released => true

    Ebook.algolia_must_reindex?(ebook).should == true # Because it's defined in algolia_dirty? method
    ebook.current_time = 10
    ebook.published_at = 8
    Ebook.algolia_must_reindex?(ebook).should == true
    ebook.published_at = 12
    Ebook.algolia_must_reindex?(ebook).should == false
  end

  it "should know if the _changed? method is user-defined", :skip => Object.const_defined?(:RUBY_VERSION) && RUBY_VERSION.to_f < 1.9 do
    color = Color.new :name => "dark-blue", :short_name => "blue"

    expect { Color.send(:automatic_changed_method?, color, :something_that_doesnt_exist) }.to raise_error(ArgumentError)

    Color.send(:automatic_changed_method?, color, :name_changed?).should == true
    Color.send(:automatic_changed_method?, color, :hex_changed?).should == false

    Color.send(:automatic_changed_method?, color, :will_save_change_to_short_name?).should == false

    if Color.send(:automatic_changed_method_deprecated?)
      Color.send(:automatic_changed_method?, color, :will_save_change_to_name?).should == true
      Color.send(:automatic_changed_method?, color, :will_save_change_to_hex?).should == true
    end

  end

end

describe 'Namespaced::Model' do
  before(:all) do
    Namespaced::Model.index.delete!
  end

  it "should have an index name without :: hierarchy" do
    (Namespaced::Model.index_name.end_with?("Namespaced_Model")).should == true
  end

  it "should use the block to determine attribute's value" do
    m = Namespaced::Model.new(:another_private_value => 2)
    attributes = Namespaced::Model.algoliasearch_settings.get_attributes(m)
    attributes['customAttr'].should == 42
    attributes['myid'].should == m.id
  end

  it "should always update when there is no custom _changed? function" do
    m = Namespaced::Model.new(:another_private_value => 2)
    m.save
    results = Namespaced::Model.search(42)
    expect(results.size).to eq(1)
    expect(results[0].id).to eq(m.id)

    m.another_private_value = 5
    m.save

    results = Namespaced::Model.search(42)
    expect(results.size).to eq(0)

    results = Namespaced::Model.search(45)
    expect(results.size).to eq(1)
    expect(results[0].id).to eq(m.id)
  end
end

describe 'UniqUsers' do
  before(:all) do
    UniqUser.clear_index!(true)
  end

  it "should not use the id field" do
    UniqUser.create :name => 'fooBar'
    results = UniqUser.search('foo')
    expect(results.size).to eq(1)
  end
end

describe 'NestedItem' do
  before(:all) do
    NestedItem.clear_index!(true) rescue nil # not fatal
  end

  it "should fetch attributes unscoped" do
    @i1 = NestedItem.create :hidden => false
    @i2 = NestedItem.create :hidden => true

    @i1.children << NestedItem.create(:hidden => true) << NestedItem.create(:hidden => true)
    NestedItem.where(:id => [@i1.id, @i2.id]).reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE, true)

    result = NestedItem.index.get_object(@i1.id)
    result['nb_children'].should == 2

    result = NestedItem.raw_search('')
    result['nbHits'].should == 1

    if @i2.respond_to? :update_attributes
      @i2.update_attributes :hidden => false
    else
      @i2.update :hidden => false
    end

    result = NestedItem.raw_search('')
    result['nbHits'].should == 2
  end
end

describe 'Colors' do
  before(:all) do
    Color.clear_index!(true)
  end

  it "should be synchronous" do
    c = Color.new
    c.valid?
    c.send(:algolia_synchronous?).should == true
  end

  it "should auto index" do
    @blue = Color.create!(:name => "blue", :short_name => "b", :hex => 0xFF0000)
    results = Color.search("blue")
    expect(results.size).to eq(1)
    results.should include(@blue)
  end

  it "should return facet as well" do
    results = Color.search("", :facets => '*')
    results.raw_answer.should_not be_nil
    results.facets.should_not be_nil
    results.facets.size.should eq(1)
    results.facets['short_name']['b'].should eq(1)
  end

  it "should be raw searchable" do
    results = Color.raw_search("blue")
    results['hits'].size.should eq(1)
    results['nbHits'].should eq(1)
  end

  it "should not auto index if scoped" do
    Color.without_auto_index do
      Color.create!(:name => "blue", :short_name => "b", :hex => 0xFF0000)
    end
    expect(Color.search("blue").size).to eq(1)
    Color.reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE, true)
    expect(Color.search("blue").size).to eq(2)
  end

  it "should not be searchable with non-indexed fields" do
    @blue = Color.create!(:name => "blue", :short_name => "x", :hex => 0xFF0000)
    results = Color.search("x")
    expect(results.size).to eq(0)
  end

  it "should rank with custom hex" do
    @blue = Color.create!(:name => "red", :short_name => "r3", :hex => 3)
    @blue2 = Color.create!(:name => "red", :short_name => "r1", :hex => 1)
    @blue3 = Color.create!(:name => "red", :short_name => "r2", :hex => 2)
    results = Color.search("red")
    expect(results.size).to eq(3)
    results[0].hex.should eq(1)
    results[1].hex.should eq(2)
    results[2].hex.should eq(3)
  end

  it "should update the index if the attribute changed" do
    @purple = Color.create!(:name => "purple", :short_name => "p")
    expect(Color.search("purple").size).to eq(1)
    expect(Color.search("pink").size).to eq(0)
    @purple.name = "pink"
    @purple.save
    expect(Color.search("purple").size).to eq(0)
    expect(Color.search("pink").size).to eq(1)
  end

  it "should use the specified scope" do
    Color.clear_index!(true)
    Color.where(:name => 'red').reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE, true)
    expect(Color.search("").size).to eq(3)
    Color.clear_index!(true)
    Color.where(:id => Color.first.id).reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE, true)
    expect(Color.search("").size).to eq(1)
  end

  it "should have a Rails env-based index name" do
    Color.index_name.should == safe_index_name("Color") + "_#{Rails.env}"
  end

  it "should add tags" do
    @blue = Color.create!(:name => "green", :short_name => "b", :hex => 0xFF0000)
    results = Color.search("green", { :tagFilters => 'green' })
    expect(results.size).to eq(1)
    results.should include(@blue)
  end

  it "should include the _highlightResult and _snippetResults" do
    results = Color.search("gre", :attributesToSnippet => ['name'], :attributesToHighlight => ['name'])
    expect(results.size).to eq(1)
    expect(results[0].highlight_result).to_not be_nil
    expect(results[0].snippet_result).to_not be_nil
  end

  it "should index an array of objects" do
    json = Color.raw_search('')
    Color.index_objects Color.limit(1), true # reindex last color, `limit` is incompatible with the reindex! method
    json['nbHits'].should eq(Color.raw_search('')['nbHits'])
  end

  it "should not index non-saved object" do
    expect { Color.new(:name => 'purple').index!(true) }.to raise_error(ArgumentError)
    expect { Color.new(:name => 'purple').remove_from_index!(true) }.to raise_error(ArgumentError)
  end

  it "should reindex with a temporary index name based on custom index name & per_environment" do
    Color.reindex
  end

  it "should search inside facets" do
    @blue = Color.create!(:name => "blue", :short_name => "blu", :hex => 0x0000FF)
    @black = Color.create!(:name => "black", :short_name => "bla", :hex => 0x000000)
    @green = Color.create!(:name => "green", :short_name => "gre", :hex => 0x00FF00)
    facets = Color.search_for_facet_values('short_name', 'bl', :query => 'black')
    expect(facets.size).to eq(1)
    expect(facets.first['value']).to eq('bla')
    expect(facets.first['highlighted']).to eq('<em>bl</em>a')
    expect(facets.first['count']).to eq(1)
  end
end

describe 'An imaginary store' do

  before(:all) do
    Product.clear_index!(true)

    # Google products
    @blackberry = Product.create!(:name => 'blackberry', :href => "google", :tags => ['decent', 'businessmen love it'])
    @nokia = Product.create!(:name => 'nokia', :href => "google", :tags => ['decent'])

    # Amazon products
    @android = Product.create!(:name => 'android', :href => "amazon", :tags => ['awesome'])
    @samsung = Product.create!(:name => 'samsung', :href => "amazon", :tags => ['decent'])
    @motorola = Product.create!(:name => 'motorola', :href => "amazon", :tags => ['decent'],
      :description => "Not sure about features since I've never owned one.")

    # Ebay products
    @palmpre = Product.create!(:name => 'palmpre', :href => "ebay", :tags => ['discontinued', 'worst phone ever'])
    @palm_pixi_plus = Product.create!(:name => 'palm pixi plus', :href => "ebay", :tags => ['terrible'])
    @lg_vortex = Product.create!(:name => 'lg vortex', :href => "ebay", :tags => ['decent'])
    @t_mobile = Product.create!(:name => 't mobile', :href => "ebay", :tags => ['terrible'])

    # Yahoo products
    @htc = Product.create!(:name => 'htc', :href => "yahoo", :tags => ['decent'])
    @htc_evo = Product.create!(:name => 'htc evo', :href => "yahoo", :tags => ['decent'])
    @ericson = Product.create!(:name => 'ericson', :href => "yahoo", :tags => ['decent'])

    # Apple products
    @iphone = Product.create!(:name => 'iphone', :href => "apple", :tags => ['awesome', 'poor reception'],
      :description => 'Puts even more features at your fingertips')

    # Unindexed products
    @sekrit = Product.create!(:name => 'super sekrit', :href => "amazon", :release_date => Time.now + 1.day)
    @no_href = Product.create!(:name => 'super sekrit too; missing href')

    # Subproducts
    @camera = Camera.create!(:name => 'canon eos rebel t3', :href => 'canon')

    100.times do ; Product.create!(:name => 'crapoola', :href => "crappy", :tags => ['crappy']) ; end

    @products_in_database = Product.all

    Product.reindex(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE, true)
    sleep 5
  end

  it "should not be synchronous" do
    p = Product.new
    p.valid?
    p.send(:algolia_synchronous?).should == false
  end

  describe 'pagination' do
    it 'should display total results correctly' do
      results = Product.search('crapoola', :hitsPerPage => AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE)
      results.length.should == Product.where(:name => 'crapoola').count
    end
  end

  describe 'basic searching' do

    it 'should find the iphone' do
      results = Product.search('iphone')
      expect(results.size).to eq(1)
      results.should include(@iphone)
    end

    it "should search case insensitively" do
      results = Product.search('IPHONE')
      expect(results.size).to eq(1)
      results.should include(@iphone)
    end

    it 'should find all amazon products' do
      results = Product.search('amazon')
      expect(results.size).to eq(3)
      results.should include(@android, @samsung, @motorola)
    end

    it 'should find all "palm" phones with wildcard word search' do
      results = Product.search('pal')
      expect(results.size).to eq(2)
      results.should include(@palmpre, @palm_pixi_plus)
    end

    it 'should search multiple words from the same field' do
      results = Product.search('palm pixi plus')
      expect(results.size).to eq(1)
      results.should include(@palm_pixi_plus)
    end

    it "should narrow the results by searching across multiple fields" do
      results = Product.search('apple iphone')
      expect(results.size).to eq(1)
      results.should include(@iphone)
    end

    it "should not search on non-indexed fields" do
      results = Product.search('features')
      expect(results.size).to eq(0)
    end

    it "should delete the associated record" do
      @iphone.destroy
      results = Product.search('iphone')
      expect(results.size).to eq(0)
    end

    it "should not throw an exception if a search result isn't found locally" do
      Product.without_auto_index { @palmpre.destroy }
      expect { Product.search('pal').to_json }.to_not raise_error
    end

    it 'should return the other results if those are still available locally' do
      Product.without_auto_index { @palmpre.destroy }
      JSON.parse(Product.search('pal').to_json).size.should == 1
    end

    it "should not duplicate an already indexed record" do
      expect(Product.search('nokia').size).to eq(1)
      @nokia.index!
      expect(Product.search('nokia').size).to eq(1)
      @nokia.index!
      @nokia.index!
      expect(Product.search('nokia').size).to eq(1)
    end

    it "should not duplicate while reindexing" do
      n = Product.search('', :hitsPerPage => AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE).length
      Product.reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE, true)
      expect(Product.search('', :hitsPerPage => AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE).size).to eq(n)
      Product.reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE, true)
      Product.reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE, true)
      expect(Product.search('', :hitsPerPage => AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE).size).to eq(n)
    end

    it "should not return products that are not indexable" do
      @sekrit.index!
      @no_href.index!
      results = Product.search('sekrit')
      expect(results.size).to eq(0)
    end

    it "should include items belong to subclasses" do
      @camera.index!
      results = Product.search('eos rebel')
      expect(results.size).to eq(1)
      results.should include(@camera)
    end

    it "should delete a not-anymore-indexable product" do
      results = Product.search('sekrit')
      expect(results.size).to eq(0)

      @sekrit.release_date = Time.now - 1.day
      @sekrit.save!
      @sekrit.index!(true)
      results = Product.search('sekrit')
      expect(results.size).to eq(1)

      @sekrit.release_date = Time.now + 1.day
      @sekrit.save!
      @sekrit.index!(true)
      results = Product.search('sekrit')
      expect(results.size).to eq(0)
    end

    it "should delete not-anymore-indexable product while reindexing" do
      n = Product.search('', :hitsPerPage => AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE).size
      Product.where(:release_date => nil).first.update_attribute :release_date, Time.now + 1.day
      Product.reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE, true)
      expect(Product.search('', :hitsPerPage => AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE).size).to eq(n - 1)
    end

    it "should find using synonyms" do
      expect(Product.search('pomme').size).to eq(Product.search('apple').size)
    end
  end

end

describe 'Cities' do
  before(:all) do
    City.clear_index!(true)
  end

  it "should index geo" do
    sf = City.create :name => 'San Francisco', :country => 'USA', :lat => 37.75, :lng => -122.68
    mv = City.create :name => 'Mountain View', :country => 'No man\'s land', :lat => 37.38, :lng => -122.08
    sf_and_mv = City.create :name => 'San Francisco & Mountain View', :country => 'Hybrid', :gl_array => [{ :lat => 37.75, :lng => -122.68 }, { :lat => 37.38, :lng => -122.08 }]
    results = City.search('', { :aroundLatLng => "37.33, -121.89", :aroundRadius => 50000 })
    expect(results.size).to eq(2)
    results.should include(mv, sf_and_mv)

    results = City.search('', { :aroundLatLng => "37.33, -121.89", :aroundRadius => 500000 })
    expect(results.size).to eq(3)
    results.should include(mv)
    results.should include(sf)
    results.should include(sf_and_mv)
  end

  it "should be searchable using replica index" do
    r = City.index(safe_index_name('City_replica1')).search 'no land'
    r['nbHits'].should eq(1)
  end

  it "should be searchable using replica index 2" do
    r = City.raw_search 'no land', :index => safe_index_name('City_replica1')
    r['nbHits'].should eq(1)
  end

  it "should be searchable using replica index 3" do
    r = City.raw_search 'no land', :replica => safe_index_name('City_replica1')
    r['nbHits'].should eq(1)
  end

  it "should be searchable using replica index 4" do
    r = City.search 'no land', :index => safe_index_name('City_replica1')
    r.size.should eq(1)
  end

  it "should be searchable using replica index 5" do
    r = City.search 'no land', :replica => safe_index_name('City_replica1')
    r.size.should eq(1)
  end

  it "should reindex with replicas in place" do
    City.reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE, true)
    expect(City.index.get_settings['replicas'].length).to eq(2)
  end

  it "should reindex with replicas using a temporary index" do
    City.reindex(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE, true)
    expect(City.index.get_settings['replicas'].length).to eq(2)
  end

  it "should not include the replicas setting on replicas" do
    City.send(:algolia_configurations).to_a.each do |v|
      if v[0][:replica]
        expect(v[1].to_settings[:replicas]).to be_nil
      else
        expect(v[1].to_settings[:replicas]).to match_array(["#{safe_index_name('City_replica1')}_#{Rails.env}", "#{safe_index_name('City_replica2')}_#{Rails.env}"])
      end
    end
  end

  it "should browse" do
    total = City.index.search('')['nbHits']
    n = 0
    City.index.browse_objects do |hit|
      n += 1
    end
    expect(n).to eq(total)
  end

  it "should have set the custom ranking on all indices" do
    expect(City.index.get_settings['customRanking']).to eq(['desc(b)'])
    expect(City.index(safe_index_name('City_replica1')).get_settings['customRanking']).to eq(['asc(a)'])
    expect(City.index(safe_index_name('City_replica2')).get_settings['customRanking']).to eq(['asc(a)', 'desc(c)'])
  end

end

describe "FowardToReplicas" do
  before(:each) do
    Object.send(:remove_const, :ForwardToReplicas) if Object.constants.include?(:ForwardToReplicas)

    class ForwardToReplicas < ActiveRecord::Base
      include AlgoliaSearch

      algoliasearch :synchronous => true, :index_name => safe_index_name('ForwardToReplicas') do
        attribute :name
        attributesToIndex %w(first_value)
        attributesToHighlight %w(primary_highlight)

        add_replica safe_index_name('ForwardToReplicas_replica') do
          attributesToHighlight %w(replica_highlight)
        end
      end
    end
  end

  after(:each) do
    ForwardToReplicas.index.delete!
  end

  it 'shouldn\'t have inherited from the primary' do
    ForwardToReplicas.send :algolia_ensure_init

    # Hacky way to have a wait on set_settings
    ForwardToReplicas.create(:name => 'val')
    ForwardToReplicas.reindex!

    primary_settings = ForwardToReplicas.index.get_settings
    expect(primary_settings['attributesToIndex']).to eq(%w(first_value))
    expect(primary_settings['attributesToHighlight']).to eq(%w(primary_highlight))

    replica_settings = ForwardToReplicas.index(safe_index_name('ForwardToReplicas_replica')).get_settings
    expect(replica_settings['attributesToIndex']).to eq(nil)
    expect(replica_settings['attributesToHighlight']).to eq(%w(replica_highlight))
  end

  it 'should update the replica settings when changed' do
    Object.send(:remove_const, :ForwardToReplicasTwo) if Object.constants.include?(:ForwardToReplicasTwo)

    class ForwardToReplicasTwo < ActiveRecord::Base
      include AlgoliaSearch

      algoliasearch :synchronous => true, :index_name => safe_index_name('ForwardToReplicas') do
        attribute :name
        attributesToIndex %w(second_value)
        attributesToHighlight %w(primary_highlight)

        add_replica safe_index_name('ForwardToReplicas_replica'), :inherit => true do
          attributesToHighlight %w(replica_highlight)
        end
      end
    end

    ForwardToReplicas.send :algolia_ensure_init

    ForwardToReplicasTwo.send :algolia_ensure_init

    # Hacky way to have a wait on set_settings
    ForwardToReplicasTwo.create(:name => 'val')
    ForwardToReplicasTwo.reindex!

    primary_settings = ForwardToReplicas.index.get_settings
    expect(primary_settings['attributesToIndex']).to eq(%w(second_value))
    expect(primary_settings['attributesToHighlight']).to eq(%w(primary_highlight))

    replica_settings = ForwardToReplicas.index(safe_index_name('ForwardToReplicas_replica')).get_settings
    expect(replica_settings['attributesToIndex']).to eq(%w(second_value))
    expect(replica_settings['attributesToHighlight']).to eq(%w(replica_highlight))

    expect(ForwardToReplicas.index.name).to eq(ForwardToReplicasTwo.index.name)
  end
end

describe "SubReplicas" do
  before(:all) do
    SubReplicas.clear_index!(true)
  end

  let(:expected_indicies) { %w(SubReplicas Additional_Index Replica_Index).map { |name| safe_index_name(name) } }

  it "contains all levels in algolia_configurations" do
    configured_indicies = SubReplicas.send(:algolia_configurations)
    configured_indicies.each_pair do |opts, _|
      expect(expected_indicies).to include(opts[:index_name])

      expect(opts[:replica]).to be true if opts[:index_name] == safe_index_name('Replica_Index')
    end
  end

  it "should be searchable through default index" do
    expect { SubReplicas.raw_search('something') }.not_to raise_error
  end

  it "should be searchable through added index" do
    expect { SubReplicas.raw_search('something', :index => safe_index_name('Additional_Index')) }.not_to raise_error
  end

  it "should be searchable through added indexes replica" do
    expect { SubReplicas.raw_search('something', :index => safe_index_name('Replica_Index')) }.not_to raise_error
  end
end

describe "WithSlave" do
  before(:all) do
    WithSlave.clear_index!(true)
  end

  let(:expected_indices) { %w(WithSlave WithSlave_slave).map { |name| safe_index_name(name) } }

  it "should be searchable through added indexes slaves" do
    expect { WithSlave.raw_search('something', :index => safe_index_name('WithSlave_slave')) }.not_to raise_error
  end

  it "should reindex with slaves in place" do
    WithSlave.reindex!
    expect(WithSlave.index.get_settings['slaves'].length).to eq(1)
  end
end

describe "SlaveThenReplica" do
  it 'should throw with add_slave then add_replica' do
    test = lambda do
      class SlaveThenReplica
        include AlgoliaSearch

        algoliasearch :synchronous => true, :force_utf8_encoding => true, :index_name => safe_index_name("SlaveThenReplica") do
          add_slave safe_index_name("SlaveThenReplica_slave") do
          end
          add_replica safe_index_name("SlaveThenReplica_replica") do
          end
        end
      end
    end
    expect(test).to raise_error(AlgoliaSearch::MixedSlavesAndReplicas)
  end
end

describe "ReplicaThenSlave" do
  it 'should throw with add_replice then add_slave' do
    test = lambda do
      class ReplicaThenSlave
        include AlgoliaSearch

        algoliasearch :synchronous => true, :force_utf8_encoding => true, :index_name => safe_index_name("ReplicaThenSlave") do
          add_replica safe_index_name("ReplicaThenSlave_replica") do
          end
          add_slave safe_index_name("ReplicaThenSlave_slave") do
          end
        end
      end
    end
    expect(test).to raise_error(AlgoliaSearch::MixedSlavesAndReplicas)
  end
end

describe 'MongoObject' do
  it "should not have method conflicts" do
    expect { MongoObject.reindex! }.to raise_error(NameError)
    expect { MongoObject.new.index! }.to raise_error(NameError)
    MongoObject.algolia_reindex!
    MongoObject.create(:name => 'mongo').algolia_index!
  end
end

describe 'Book' do
  before(:all) do
    Book.clear_index!(true)
    Book.index(safe_index_name('BookAuthor')).clear_objects
    Book.index(safe_index_name('Book')).clear_objects
  end

  it "should index the book in 2 indexes of 3" do
    @steve_jobs = Book.create! :name => 'Steve Jobs', :author => 'Walter Isaacson', :premium => true, :released => true
    results = Book.search('steve')
    expect(results.size).to eq(1)
    results.should include(@steve_jobs)

    index_author = Book.index(safe_index_name('BookAuthor'))
    index_author.should_not be_nil
    results = index_author.search('steve')
    results['hits'].length.should eq(0)
    results = index_author.search('walter')
    results['hits'].length.should eq(1)

    # premium -> not part of the public index
    index_book = Book.index(safe_index_name('Book'))
    index_book.should_not be_nil
    results = index_book.search('steve')
    results['hits'].length.should eq(0)
  end

  it "should sanitize attributes" do
    @hack = Book.create! :name => "\"><img src=x onerror=alert(1)> hack0r", :author => "<script type=\"text/javascript\">alert(1)</script>", :premium => true, :released => true
    b = Book.raw_search('hack')
    expect(b['hits'].length).to eq(1)
    begin
      expect(b['hits'][0]['name']).to eq('"> hack0r')
      expect(b['hits'][0]['author']).to eq('alert(1)')
      expect(b['hits'][0]['_highlightResult']['name']['value']).to eq('"> <em>hack</em>0r')
    rescue
      # rails 4.2's sanitizer
      begin
        expect(b['hits'][0]['name']).to eq('&quot;&gt; hack0r')
        expect(b['hits'][0]['author']).to eq('')
        expect(b['hits'][0]['_highlightResult']['name']['value']).to eq('&quot;&gt; <em>hack</em>0r')
      rescue
        # jruby
        expect(b['hits'][0]['name']).to eq('"&gt; hack0r')
        expect(b['hits'][0]['author']).to eq('')
        expect(b['hits'][0]['_highlightResult']['name']['value']).to eq('"&gt; <em>hack</em>0r')
      end
    end
  end

  it "should handle removal in an extra index" do
    # add a new public book which (not premium but released)
    book = Book.create! :name => 'Public book', :author => 'me', :premium => false, :released => true

    # should be searchable in the 'Book' index
    index = Book.index(safe_index_name('Book'))
    results = index.search('Public book')
    expect(results['hits'].size).to eq(1)

    # update the book and make it non-public anymore (not premium, not released)
    if book.respond_to? :update_attributes
      book.update_attributes :released => false
    else
      book.update :released => false
    end

    # should be removed from the index
    results = index.search('Public book')
    expect(results['hits'].size).to eq(0)
  end

  it "should use the per_environment option in the additional index as well" do
    index = Book.index(safe_index_name('Book'))
    expect(index.name).to eq("#{safe_index_name('Book')}_#{Rails.env}")
  end
end

describe 'Kaminari' do
  before(:all) do
    require 'kaminari'
    AlgoliaSearch.configuration = { :application_id => ENV['ALGOLIA_APPLICATION_ID'], :api_key => ENV['ALGOLIA_API_KEY'], :pagination_backend => :kaminari }
  end

  it "should paginate" do
    pagination = City.search ''
    pagination.total_count.should eq(City.raw_search('')['nbHits'])

    p1 = City.search '', :page => 1, :hitsPerPage => 1
    p1.size.should eq(1)
    p1[0].should eq(pagination[0])
    p1.total_count.should eq(City.raw_search('')['nbHits'])

    p2 = City.search '', :page => 2, :hitsPerPage => 1
    p2.size.should eq(1)
    p2[0].should eq(pagination[1])
    p2.total_count.should eq(City.raw_search('')['nbHits'])
  end
end

describe 'Will_paginate' do
  before(:all) do
    require 'will_paginate'
    AlgoliaSearch.configuration = { :application_id => ENV['ALGOLIA_APPLICATION_ID'], :api_key => ENV['ALGOLIA_API_KEY'], :pagination_backend => :will_paginate }
  end

  it "should paginate" do
    p1 = City.search '', :hitsPerPage => 2
    p1.length.should eq(2)
    p1.per_page.should eq(2)
    p1.total_entries.should eq(City.raw_search('')['nbHits'])
  end
end

describe 'Disabled' do
  before(:all) do
    DisabledBoolean.index.clear_objects!
    DisabledProc.index.clear_objects!
    DisabledSymbol.index.clear_objects!
  end

  it "should disable the indexing using a boolean" do
    DisabledBoolean.create :name => 'foo'
    expect(DisabledBoolean.search('').size).to eq(0)
  end

  it "should disable the indexing using a proc" do
    DisabledProc.create :name => 'foo'
    expect(DisabledProc.search('').size).to eq(0)
  end

  it "should disable the indexing using a symbol" do
    DisabledSymbol.create :name => 'foo'
    expect(DisabledSymbol.search('').size).to eq(0)
  end
end

describe 'NullableId' do
  before(:all) do
  end

  it "should not delete a null objectID" do
    NullableId.create!
  end
end

unless OLD_RAILS
  describe 'EnqueuedObject' do
    it "should enqueue a job" do
      expect {
        EnqueuedObject.create! :name => 'test'
      }.to raise_error("enqueued 1")
    end

    it "should not enqueue a job inside no index block" do
      expect {
        EnqueuedObject.without_auto_index do
          EnqueuedObject.create! :name => 'test'
        end
      }.not_to raise_error
    end
  end

  describe 'DisabledEnqueuedObject' do
    it "should not try to enqueue a job" do
      expect {
        DisabledEnqueuedObject.create! :name => 'test'
      }.not_to raise_error
    end
  end
end

describe 'Misconfigured Block' do
  it "should force the algoliasearch block" do
    expect {
      MisconfiguredBlock.reindex
    }.to raise_error(ArgumentError)
  end
end
