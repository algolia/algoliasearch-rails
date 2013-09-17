require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

require 'active_record'
require 'sqlite3'
require 'logger'

FileUtils.rm( 'data.sqlite3' ) rescue nil
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.establish_connection(
    'adapter' => 'sqlite3',
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
  end
end

class Product < ActiveRecord::Base
  include AlgoliaSearch

  scope :amazon, -> { where(href: "amazon") }

  algoliasearch auto_index: false do
    attribute :href, :name, :tags
  end

  def tags=(names)
    @tags = names.join(",")
  end
end

class Color < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch
end

describe 'Colors' do
  before(:all) do
    Color.clear_index!
  end

  it "should auto index" do
    @blue = Color.create!(name: "blue")
    results = Color.search("blue")
    results.should have_exactly(1).product
    results.should include(@blue)
  end
end

describe 'An imaginary store' do

  before(:all) do
    Product.clear_index!

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

  describe 'pagination' do
    it 'should display total results correctly' do
      results = Product.search('crapoola')
      results.total_entries.should == Product.where(name: 'crapoola').count
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

  end

end
