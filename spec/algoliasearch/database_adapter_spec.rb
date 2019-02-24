require "spec_helper"
connect_to_db("mock")

require "algoliasearch/database_adapter"

## Eager load all ORM Adapters
require "algoliasearch/database_adapter/active_record"
require "algoliasearch/database_adapter/mongoid"
require "algoliasearch/database_adapter/sequel"

## Support files for basic classes
require "support/mocked_orm_classes"

ADAPTERS = [
  { "name" => :active_record, "adapter" => DatabaseAdapter::ActiveRecord, "mocked_class" => SimpleActiveRecord },
  { "name" => :sequel, "adapter" => DatabaseAdapter::Sequel, "mocked_class" => SimpleSequel },
  { "name" => :mongoid, "adapter" => DatabaseAdapter::Mongoid, "mocked_class" => SimpleMongoid }
]

RSpec.describe DatabaseAdapter do

  ## Ensure that these specs use the mock DB setup in
  ## mocked_orm_classes.rb
  describe "public methods", mocked_db: true do

    ADAPTERS.each do | test_block |
      describe "when #{test_block['name']} object or class" do

        describe "methods sending object" do
          [:get_default_attributes, :mark_must_reindex].each do |adapter_method|
            it "delegates ##{adapter_method} to #{test_block['adapter']}" do
              # Arrange
              allow(test_block['adapter']).to receive(adapter_method)
              # Act
              DatabaseAdapter.send(adapter_method, test_block['mocked_class'].new())
              # Assert
              expect(test_block['adapter']).to have_received(adapter_method)
            end
          end

          it "delegates #get_attributes to #{test_block['adapter']}" do
            # Arrange
            allow(test_block['adapter']).to receive(:get_attributes)
            # Act
            DatabaseAdapter.get_attributes({}, test_block['mocked_class'].new())
            # Assert
            expect(test_block['adapter']).to have_received(:get_attributes)
          end
        end

        describe "methods sending klass" do
          [:prepare_for_auto_index, :prepare_for_auto_remove, :prepare_for_synchronous].each do |adapter_method|
            it "delegates ##{adapter_method} to #{test_block['adapter']}" do
              # Arrange
              allow(test_block['adapter']).to receive(adapter_method)
              # Act
              DatabaseAdapter.send(adapter_method, test_block['mocked_class'])
              # Assert
              expect(test_block['adapter']).to have_received(adapter_method)
            end
          end

          it "delegates #find_in_batches to #{test_block['adapter']}" do
            # Arrange
            allow(test_block['adapter']).to receive(:find_in_batches)
            # Act
            DatabaseAdapter.find_in_batches(test_block['mocked_class'], 10) do Proc.new { |x| x*1 } end
            # Assert
            expect(test_block['adapter']).to have_received(:find_in_batches)
          end
        end

      end
    end
  end

  describe "Private Methods" do
    describe "#adapter" do
      it "returns the adpater if it is already set" do
        # Act
        described_class.send(:adapter=, :sequel)
        # Assert
        expect(described_class.send(:adapter)).to eq DatabaseAdapter::Sequel
      end
    end

    describe "#adapter=" do
      it "errors on missing adapters" do
        # Assert
        expect { described_class.send(:adapter=, :example) }.to raise_error LoadError
      end
    end

    describe "#determine_instance" do
      it "defaults to active record" do
        # Arrange
        described_class.send(:determine_instance, Class.new())
        # Assert
        expect(described_class.instance_variable_get(:@adapter)).to eq DatabaseAdapter::ActiveRecord
      end

      it "sets sequel when is_sequel?" do
        # Arrange
        allow(described_class).to receive(:is_sequel?).and_return(true)
        # Act
        described_class.send(:determine_instance, Class.new())
        # Assert
        expect(described_class.instance_variable_get(:@adapter)).to eq DatabaseAdapter::Sequel
      end

      it "sets mongoid when is_mongoid?" do
        # Arrange
        allow(described_class).to receive(:is_mongoid?).and_return(true)
        # Act
        described_class.send(:determine_instance, Class.new())
        # Assert
        expect(described_class.instance_variable_get(:@adapter)).to eq DatabaseAdapter::Mongoid
      end
    end
  end
end
