require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

require 'active_record'
unless defined?(RUBY_VERSION) && RUBY_VERSION == "1.8.7"
  require 'active_job/test_helper'
  ActiveJob::Base.queue_adapter = :test
end
require 'sqlite3' if !defined?(JRUBY_VERSION)
require 'logger'
require 'sequel'

AlgoliaSearch.configuration = { :application_id => ENV['ALGOLIA_APPLICATION_ID'], :api_key => ENV['ALGOLIA_API_KEY'] }

FileUtils.rm( 'data.sqlite3' ) rescue nil
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::WARN
ActiveRecord::Base.establish_connection(
    'adapter' => defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3',
    'database' => 'data.sqlite3',
    'pool' => 5,
    'timeout' => 5000
)
ActiveRecord::Base.raise_in_transactional_callbacks = true unless defined?(RUBY_VERSION) && RUBY_VERSION == "1.8.7"

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

  algoliasearch :synchronous => true, :index_name => safe_index_name("Color"), :per_environment => true do
    attributesToIndex [:name]
    attributesForFaceting [:short_name]
    customRanking ["asc(hex)"]
    tags do
      name # single tag
    end
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

  algoliasearch do
    attribute :customAttr do
      40 + another_private_value
    end
    attribute :myid do
      id
    end
    tags ['static_tag1', 'static_tag2']
  end

  private
  def another_private_value
    2
  end
end

class UniqUser < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :synchronous => true, :index_name => safe_index_name("UniqUser"), :per_environment => true, :id => :name do
  end
end

class NullableId < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :synchronous => true, :index_name => safe_index_name("NullableId"), :per_environment => true, :id => :custom_id, if: :never do
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

class City < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :synchronous => true, :index_name => safe_index_name("City"), :per_environment => true do
    geoloc :lat, :lng

    add_slave safe_index_name('City_slave1'), :per_environment => true do
      attributesToIndex [:country]
    end
  end
end

class SequelBook < Sequel::Model
  plugin :active_model

  include AlgoliaSearch

  algoliasearch :synchronous => true, :index_name => safe_index_name("SequelBook"), :per_environment => true, :sanitize => true do
    attributesToIndex [:name]
  end

  def after_create
    SequelBook.new
  end

  private
  def public?
    released && !premium
  end
end
SequelBook.db = SEQUEL_DB

describe 'SequelBook' do
  before(:all) do
    SequelBook.clear_index!(true)
  end

  it "should index the book" do
    @steve_jobs = SequelBook.create :name => 'Steve Jobs', :author => 'Walter Isaacson', :premium => true, :released => true
    results = SequelBook.search('steve')
    expect(results.size).to eq(1)
    results.should include(@steve_jobs)
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

class EncodedString < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch :synchronous => true, :force_utf8_encoding => true, :index_name => safe_index_name("EncodedString") do
    attribute :value do
      "\xC2\xA0\xE2\x80\xA2\xC2\xA0".force_encoding('ascii-8bit')
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

describe 'Namespaced::Model' do
  it "should have an index name without :: hierarchy" do
    Namespaced::Model.index_name.should == "Namespaced_Model"
  end

  it "should use the block to determine attribute's value" do
    m = Namespaced::Model.new
    attributes = Namespaced::Model.algoliasearch_settings.get_attributes(m)
    attributes['customAttr'].should == 42
    attributes['myid'].should == m.id
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
    NestedItem.where(:id => [@i1.id, @i2.id]).reindex!(1000, true)

    result = NestedItem.index.get_object(@i1.id)
    result['nb_children'].should == 2

    result = NestedItem.raw_search('')
    result['nbHits'].should == 1

    @i2.update_attributes :hidden => false

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
    Color.reindex!(1000, true)
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
    Color.where(:name => 'red').reindex!(1000, true)
    expect(Color.search("").size).to eq(3)
    Color.clear_index!(true)
    Color.where(:id => Color.first.id).reindex!(1000, true)
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

    Product.reindex(1000, true)
  end

  it "should not be synchronous" do
    p = Product.new
    p.valid?
    p.send(:algolia_synchronous?).should == false
  end

  describe 'pagination' do
    it 'should display total results correctly' do
      results = Product.search('crapoola', :hitsPerPage => 1000)
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
      n = Product.search('', :hitsPerPage => 1000).length
      Product.reindex!(1000, true)
      expect(Product.search('', :hitsPerPage => 1000).size).to eq(n)
      Product.reindex!(1000, true)
      Product.reindex!(1000, true)
      expect(Product.search('', :hitsPerPage => 1000).size).to eq(n)
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
      n = Product.search('', :hitsPerPage => 1000).size
      Product.where(:release_date => nil).first.update_attribute :release_date, Time.now + 1.day
      Product.reindex!(1000, true)
      expect(Product.search('', :hitsPerPage => 1000).size).to eq(n - 1)
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
    results = City.search('', { :aroundLatLng => "37.33, -121.89", :aroundRadius => 50000 })
    expect(results.size).to eq(1)
    results.should include(mv)

    results = City.search('', { :aroundLatLng => "37.33, -121.89", :aroundRadius => 500000 })
    expect(results.size).to eq(2)
    results.should include(mv)
    results.should include(sf)
  end

  it "should be searchable using slave index" do
    r = City.index(safe_index_name('City_slave1')).search 'no land'
    r['nbHits'].should eq(1)
  end

  it "should be searchable using slave index 2" do
    r = City.raw_search 'no land', :index => safe_index_name('City_slave1')
    r['nbHits'].should eq(1)
  end

  it "should be searchable using slave index 3" do
    r = City.raw_search 'no land', :slave => safe_index_name('City_slave1')
    r['nbHits'].should eq(1)
  end

  it "should be searchable using slave index 4" do
    r = City.search 'no land', :index => safe_index_name('City_slave1')
    r.size.should eq(1)
  end

  it "should be searchable using slave index 5" do
    r = City.search 'no land', :slave => safe_index_name('City_slave1')
    r.size.should eq(1)
  end

  it "should reindex with slaves in place" do
    City.reindex!(1000, true)
    expect(City.index.get_settings['slaves'].length).to eq(1)
  end

  it "should reindex with slaves using a temporary index" do
    City.reindex(1000, true)
    expect(City.index.get_settings['slaves'].length).to eq(1)
  end

  it "should not include the slaves setting on slaves" do
    City.send(:algolia_configurations).to_a.each do |v|
      if v[0][:slave]
        expect(v[1].to_settings[:slaves]).to be_nil
      else
        expect(v[1].to_settings[:slaves]).to eq(["#{safe_index_name('City_slave1')}_#{Rails.env}"])
      end
    end
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
    Book.index(safe_index_name('BookAuthor')).clear
    Book.index(safe_index_name('Book')).clear
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
    book.update_attributes :released => false

    # should be removed from the index
    results = index.search('Public book')
    expect(results['hits'].size).to eq(0)
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
    DisabledBoolean.index.clear_index!
    DisabledProc.index.clear_index!
    DisabledSymbol.index.clear_index!
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

