require "algoliasearch/database_adapter"
require "algoliasearch/database_adapter/active_record"
require "algoliasearch/database_adapter/mongoid"
require "algoliasearch/database_adapter/sequel"

RSpec.describe DatabaseAdapter do
  describe "public methods" do

    describe "methods sending object" do
      [:get_default_attributes, :get_attributes, :mark_must_reindex].each do |adapter_method|
        it "delegates ##{adapter_method} to the ORM adapter" do
          # Arrange
          allow(DatabaseAdapter::ActiveRecord).to receive(:get_default_attributes)
          # Act
          DatabaseAdapter.get_default_attributes(Class.new())
          # Assert
          expect(DatabaseAdapter::ActiveRecord).to have_received(:get_default_attributes)
        end
      end
    end

    describe "methods sending klass" do
      [:prepare_for_auto_index, :prepare_for_auto_remove, :prepare_for_synchronous].each do |adapter_method|
        it "delegates ##{adapter_method} to the ORM adapter" do
          # Arrange
          allow(DatabaseAdapter::ActiveRecord).to receive(:get_default_attributes)
          # Act
          DatabaseAdapter.get_default_attributes(Class)
          # Assert
          expect(DatabaseAdapter::ActiveRecord).to have_received(:get_default_attributes)
        end

      end
      it "delegates #find_in_batches to the ORM adapter" do
        # Arrange
        allow(DatabaseAdapter::ActiveRecord).to receive(:find_in_batches)
        # Act
        DatabaseAdapter.find_in_batches(Class, 10) do Proc.new { |x| x*1 } end
        # Assert
        expect(DatabaseAdapter::ActiveRecord).to have_received(:find_in_batches)
      end
    end

  end

  describe "Private Methods" do
    describe "#adapter" do
      it "sets a default of active_record" do
        # Assert
        expect(described_class.send(:adapter)).to eq DatabaseAdapter::ActiveRecord
      end

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
