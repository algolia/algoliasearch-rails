require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

require 'active_record'
require 'sqlite3' if !defined?(JRUBY_VERSION)
require 'logger'

class Rails
  def self.env
    "fake"
  end
end

FileUtils.rm( 'data.sqlite3' ) rescue nil
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::WARN
ActiveRecord::Base.establish_connection(
    'adapter' => defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3',
    'database' => 'data.sqlite3',
    'pool' => 5,
    'timeout' => 5000
)

ActiveRecord::Schema.define do
  create_table :products do |t|
    t.string :name
    t.string :href
    t.string :tags
    t.text :description
  end
  create_table :colors do |t|
    t.string :name
    t.string :short_name
    t.integer :hex
  end
  create_table :namespaced_models do |t|
    t.string :name
  end
  create_table :uniq_users, id: false do |t|
    t.string :name
  end
  create_table :nested_items do |t|
    t.integer :parent_id
  end
  create_table :cities do |t|
    t.string :name
    t.float :lat
    t.float :lng
  end
  create_table :mongo_objects do |t|
    t.string :name
  end
end

# avoid concurrent access to the same index
def safe_index_name(name)
  return name if ENV['TRAVIS'].to_s != "true"
  id = ENV['TRAVIS_JOB_NUMBER'].split('.').last
  "#{name}_travis-#{id}"
end

class Product < ActiveRecord::Base
  include AlgoliaSearch

  scope :amazon, -> { where(href: "amazon") }

  algoliasearch auto_index: false, index_name: safe_index_name("my_products_index") do
    attribute :href, :name, :tags
    tags do
      [name, name] # multiple tags
    end
  end

  def tags=(names)
    @tags = names.join(",")
  end
end

class Color < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch synchronous: true, index_name: safe_index_name("Color"), per_environment: true do
    attributesToIndex [:name]
    customRanking ["asc(hex)"]
    tags do
      name # single tag
    end
  end
end

module Namespaced
  def self.table_name_prefix
    'namespaced_'
  end
end
class Namespaced::Model < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch synchronous: true do
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

  algoliasearch synchronous: true, index_name: safe_index_name("UniqUser"), per_environment: true, id: :name do
  end
end

class NestedItem < ActiveRecord::Base
  has_many :children, class_name: "NestedItem", foreign_key: "parent_id"

  include AlgoliaSearch

  algoliasearch synchronous: true, index_name: safe_index_name("UniqUser"), per_environment: true do
    attribute :nb_children
  end

  def nb_children
    children.count
  end
end

class City < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch synchronous: true, index_name: safe_index_name("City"), per_environment: true do
    geoloc :lat, :lng
  end
end

class MongoObject < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch do
  end

  def self.reindex!
    raise NameError.new("never reached")
  end

  def index!
    raise NameError.new("never reached")
  end
end

describe 'Settings' do

  it "should detect settings changes" do
    Color.send(:algolia_index_settings_changed?, nil, {}).should be_true
    Color.send(:algolia_index_settings_changed?, {}, {"attributesToIndex" => ["name"]}).should be_true
    Color.send(:algolia_index_settings_changed?, {"attributesToIndex" => ["name"]}, {"attributesToIndex" => ["name", "hex"]}).should be_true
    Color.send(:algolia_index_settings_changed?, {"attributesToIndex" => ["name"]}, {"customRanking" => ["asc(hex)"]}).should be_true
  end

  it "should not detect settings changes" do
    Color.send(:algolia_index_settings_changed?, {}, {}).should be_false
    Color.send(:algolia_index_settings_changed?, {"attributesToIndex" => ["name"]}, {attributesToIndex: ["name"]}).should be_false
    Color.send(:algolia_index_settings_changed?, {"attributesToIndex" => ["name"], "customRanking" => ["asc(hex)"]}, {"customRanking" => ["asc(hex)"]}).should be_false
  end

end

describe 'Namespaced::Model' do
  before(:all) do
    Namespaced::Model.clear_index!(true)
  end

  it "should have an index name without :: hierarchy" do
    Namespaced::Model.index_name.should == "Namespaced_Model"
  end

  it "should use the block to determine attribute's value" do
    m = Namespaced::Model.create!
    attributes = Namespaced::Model.instance_variable_get(:@algolia_index_settings).get_attributes(m)
    attributes['customAttr'].should == 42
    attributes['myid'].should == m.id
    Namespaced::Model.search('').length.should == 1
  end
end

describe 'UniqUsers' do
  before(:all) do
    UniqUser.clear_index!(true)
  end

  it "should not use the id field" do
    u = UniqUser.create name: 'fooBar'
    results = UniqUser.search('foo')
    results.should have_exactly(1).uniq_users
  end
end

describe 'NestedItem' do
  before(:all) do
    NestedItem.clear_index!(true)
  end

  it "should fetch attributes unscoped" do
    @i1 = NestedItem.create
    @i2 = NestedItem.create

    @i1.children << NestedItem.create << NestedItem.create
    NestedItem.where(id: [@i1.id, @i2.id]).reindex!(1000, true)

    result = NestedItem.index.get_object(@i1.id)
    result['nb_children'].should == 2
  end
end

describe 'Colors' do
  before(:all) do
    Color.clear_index!(true)
  end

  it "should be synchronous" do
    c = Color.new
    c.valid?
    c.send(:algolia_synchronous?).should be_true
  end

  it "should auto index" do
    @blue = Color.create!(name: "blue", short_name: "b", hex: 0xFF0000)
    results = Color.search("blue")
    results.should have_exactly(1).product
    results.should include(@blue)
  end

  it "should not auto index if scoped" do
    Color.without_auto_index do
      Color.create!(name: "blue", short_name: "b", hex: 0xFF0000)
    end
    Color.search("blue").should have_exactly(1).product
    Color.reindex!(1000, true)
    Color.search("blue").should have_exactly(2).product
  end

  it "should not be searchable with non-indexed fields" do
    @blue = Color.create!(name: "blue", short_name: "x", hex: 0xFF0000)
    results = Color.search("x")
    results.should have_exactly(0).product
  end

  it "should rank with custom hex" do
    @blue = Color.create!(name: "red", short_name: "r3", hex: 3)
    @blue2 = Color.create!(name: "red", short_name: "r1", hex: 1)
    @blue3 = Color.create!(name: "red", short_name: "r2", hex: 2)
    results = Color.search("red")
    results.should have_exactly(3).product
    results[0].hex.should eq(1)
    results[1].hex.should eq(2)
    results[2].hex.should eq(3)
  end

  it "should update the index if the attribute changed" do
    @purple = Color.create!(name: "purple", short_name: "p")
    Color.search("purple").should have_exactly(1).product
    Color.search("pink").should have_exactly(0).product
    @purple.name = "pink"
    @purple.save
    Color.search("purple").should have_exactly(0).product
    Color.search("pink").should have_exactly(1).product
  end

  it "should use the specified scope" do
    Color.clear_index!(true)
    Color.where(name: 'red').reindex!(1000, true)
    Color.search("").should have_exactly(3).product
    Color.clear_index!(true)
    Color.where(id: Color.first.id).reindex!(1000, true)
    Color.search("").should have_exactly(1).product
  end

  it "should have a Rails env-based index name" do
    Color.index_name.should == safe_index_name("Color") + "_#{Rails.env}"
  end

  it "should add tags" do
    @blue = Color.create!(name: "green", short_name: "b", hex: 0xFF0000)
    results = Color.search("green", { tagFilters: 'green' })
    results.should have_exactly(1).product
    results.should include(@blue)
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

    100.times do ; Product.create!(:name => 'crapoola', :href => "crappy", :tags => ['crappy']) ; end

    @products_in_database = Product.all

    Product.reindex!
  end

  it "should not be synchronous" do
    p = Product.new
    p.valid?
    p.send(:algolia_synchronous?).should be_false
  end

  describe 'pagination' do
    it 'should display total results correctly' do
      results = Product.search('crapoola', hitsPerPage: 1000)
      results.length.should == Product.where(name: 'crapoola').count
    end
  end

  describe 'basic searching' do

    it 'should find the iphone' do
      results = Product.search('iphone')
      results.should have_exactly(1).product
      results.should include(@iphone)
    end

    it "should search case insensitively" do
      results = Product.search('IPHONE')
      results.should have(1).product
      results.should include(@iphone)
    end

    it 'should find all amazon products' do
      results = Product.search('amazon')
      results.should have_exactly(3).products
      results.should include(@android, @samsung, @motorola)
    end

    it 'should find all "palm" phones with wildcard word search' do
      results = Product.search('pal')
      results.should have_exactly(2).products
      results.should include(@palmpre, @palm_pixi_plus)
    end

    it 'should search multiple words from the same field' do
      results = Product.search('palm pixi plus')
      results.should have_exactly(1).product
      results.should include(@palm_pixi_plus)
    end

    it "should narrow the results by searching across multiple fields" do
      results = Product.search('apple iphone')
      results.should have_exactly(1).product
      results.should include(@iphone)
    end

    it "should not search on non-indexed fields" do
      results = Product.search('features')
      results.should have_exactly(0).product
    end

    it "should delete the associated record" do
      @iphone.destroy
      results = Product.search('iphone')
      results.should have_exactly(0).product
    end

    it "should not duplicate an already indexed record" do
      Product.search('nokia').should have_exactly(1).product
      @nokia.index!
      Product.search('nokia').should have_exactly(1).product
      @nokia.index!
      @nokia.index!
      Product.search('nokia').should have_exactly(1).product
    end

    it "should not duplicate while reindexing" do
      n = Product.search('', hitsPerPage: 1000).length
      Product.reindex!(1000, true)
      Product.search('', hitsPerPage: 1000).should have_exactly(n).product
      Product.reindex!(1000, true)
      Product.reindex!(1000, true)
      Product.search('', hitsPerPage: 1000).should have_exactly(n).product
    end

  end

end

describe 'Cities' do
  before(:all) do
    City.clear_index!(true)
  end

  it "should index geo" do
    sf = City.create name: 'San Francisco', lat: 37.75, lng: -122.68
    mv = City.create name: 'Mountain View', lat: 37.38, lng: -122.08
    results = City.search('', { aroundLatLng: "37.33, -121.89", aroundRadius: 50000 })
    results.should have_exactly(1).city
    results.should include(mv)

    results = City.search('', { aroundLatLng: "37.33, -121.89", aroundRadius: 500000 })
    results.should have_exactly(2).cities
    results.should include(mv)
    results.should include(sf)
  end
end

describe 'MongoObject' do

  it "should not have method conflicts" do
    expect { MongoObject.reindex! }.to raise_error(NameError)
    expect { MongoObject.new.index! }.to raise_error(NameError)
    MongoObject.algolia_reindex!
    MongoObject.create(name: 'mongo').algolia_index!
  end
end