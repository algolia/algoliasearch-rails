shared_examples "database_adapter" do

  [
    :get_attributes, :get_default_attributes, :find_in_batches, :prepare_for_auto_index,
    :prepare_for_auto_remove, :prepare_for_synchronous, :mark_must_reindex
  ].each do |adapter_method|
    it "#{described_class} implements #{adapter_method}" do
      expect(described_class.method_defined? adapter_method).to eq true
    end
  end

end
