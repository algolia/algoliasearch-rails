require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe AlgoliaSearch::Configuration do

  before(:each) do
    @previous_client = AlgoliaSearch.instance_variable_get :@client
    if AlgoliaSearch::Configuration.class_variable_defined?(:@@configuration)
      @previous_configuration = AlgoliaSearch::Configuration.class_variable_get(:@@configuration)
    end
  end

  after(:each) do
    AlgoliaSearch.instance_variable_set :@client, @previous_client
    AlgoliaSearch.configuration = @previous_configuration unless @previous_configuration.nil?
  end

  it "should expose the client writer documented in the Rails setup guide" do
    expect(AlgoliaSearch.respond_to?(:client=)).to eq(true)

    custom_client = Algolia::SearchClient.create('client_writer_app_id', 'client_writer_api_key')
    AlgoliaSearch.client = custom_client
    expect(AlgoliaSearch.client).to equal(custom_client)
  end

  it "should forward timeouts from the configuration to the client" do
    AlgoliaSearch.configuration = {
      application_id: 'timeouts_app_id',
      api_key: 'timeouts_api_key',
      connect_timeout: 1_000,
      read_timeout: 1_500,
      write_timeout: 40_000
    }
    AlgoliaSearch.instance_variable_set :@client, nil

    config = AlgoliaSearch.client.api_client.config
    expect(config.connect_timeout).to eq(1_000)
    expect(config.read_timeout).to eq(1_500)
    expect(config.write_timeout).to eq(40_000)
  end

  it "should keep the client timeout defaults when the configuration has no timeouts" do
    AlgoliaSearch.configuration = {
      application_id: 'no_timeouts_app_id',
      api_key: 'no_timeouts_api_key'
    }
    AlgoliaSearch.instance_variable_set :@client, nil

    config = AlgoliaSearch.client.api_client.config
    baseline = Algolia::SearchClient.create('no_timeouts_app_id', 'no_timeouts_api_key').api_client.config
    expect(config.connect_timeout).to eq(baseline.connect_timeout)
    expect(config.read_timeout).to eq(baseline.read_timeout)
    expect(config.write_timeout).to eq(baseline.write_timeout)
  end

end
