module DatabaseAdapter
  extend self

  ### Adapter public methods

  # Return a hash of the attributes for the object
  #
  # @param attributes [Hash] Collection of named attribute Proc's
  # @param object [Class Instance] Instance of the ORM Object
  def get_attributes(attributes, object)
    determine_instance(object)
    adapter.get_attributes(attributes, object)
  end

  ## Return a hash of the default attributes for the object
  #
  # @param object [Class Instance] Instance of the ORM Object
  def get_default_attributes(object)
    determine_instance(object)
    adapter.get_default_attributes(object)
  end

  ## Mark an object as required for reindexing in the ORM
  #
  # @param object [Class Instance] Instance of the ORM Object
  def mark_must_reindex(object)
    determine_instance(object)
    adapter.mark_must_reindex(object)
  end

  ## Find in batches on the ORM Class
  #
  # @param klass [Class] The ORM Class
  # @param batch_size [Integer] Number of records to fetch per batch
  # @param &block [Proc] Block to evaluate in the ORM context
  def find_in_batches(klass, batch_size, &block)
    determine_class(klass)
    adapter.find_in_batches(klass, batch_size, &block)
  end

  ## Set the ORM callbacks required for auto indexing
  #
  # @param klass [Class] The ORM Class
  def prepare_for_auto_index(klass)
    determine_class(klass)
    adapter.prepare_for_auto_index(klass)
  end

  ## Set the ORM callbacks required for auto removing objects
  #
  # @param klass [Class] The ORM Class
  def prepare_for_auto_remove(klass)
    determine_class(klass)
    adapter.prepare_for_auto_remove(klass)
  end

  ## Set the ORM callbacks required for synchronous indexing
  #
  # @param klass [Class] The ORM Class
  def prepare_for_synchronous(klass)
    determine_class(klass)
    adapter.prepare_for_synchronous(klass)
  end

  ## Determine the correct changed method to send to the ORM class
  #
  # This method is not ORM specific so isn't forwared to the
  # ORM adapter. We assert the new ActiveRecord 5.1.2 method
  # as `will_save_change_to` if this is not present, return
  # the old method
  def attribute_changed_method(object, attribute_name)
    will_save_method = "will_save_change_to_#{attribute_name}?"
    did_change_method = "#{attribute_name}_changed?"

    return will_save_method if object.respond_to?(will_save_method)
    did_change_method
  end

  #### Helper Methods

  # This method is a helper for get_attributes
  #
  # @param attributes [Hash] Collection of named attribute Proc's
  # @param object [Class Instance] Instance of the ORM Object
  def attributes_to_hash(attributes, object)
    if attributes
      Hash[attributes.map { |name, value| [name.to_s, value.call(object) ] }]
    else
      {}
    end
  end

  private

  ## Return the database adapter instance (default active_record)
  def adapter
    return @adapter if @adapter
    self.adapter = :active_record
    @adapter
  end

  ## Set the database adapter
  #
  # @param adapter [Symbol] A symbol representation of the ORM
  def adapter=(adapter)
    require "algoliasearch/database_adapter/#{adapter}"
    @adapter = DatabaseAdapter.const_get(adapter.to_s.split("_").each(&:capitalize!).join)
  end

  ## ORM is evaluated per object.
  #
  # @param object [Class Instance] Instance of the ORM Object
  def determine_instance(object)
    self.adapter = :mongoid if is_mongoid?(object)
    self.adapter = :sequel if is_sequel?(object)
    self.adapter = :active_record if is_active_record?(object)
  end

  ## ORM is determined on the class
  #
  # @param klass [Class] The ORM Class
  def determine_class(klass)
    self.adapter = :mongoid if is_mongoid_class?(klass)
    self.adapter = :sequel if is_sequel_class?(klass)
    self.adapter = :active_record if is_active_record_class?(klass)
  end


  #### Database Adapter Class Determination

  def is_mongoid_class?(klass)
    defined?(::Mongoid::Document) && klass.include?(::Mongoid::Document)
  end

  def is_sequel_class?(klass)
    defined?(::Sequel) && klass < ::Sequel::Model
  end

  def is_active_record_class?(klass)
    (defined?(::ActiveRecord) && klass.ancestors.include?(::ActiveRecord::Base)) || klass.respond_to?(:find_in_batches)
  end

  #### Database Adapter Object Determination

  def is_mongoid?(object)
    defined?(::Mongoid::Document) && object.class.include?(::Mongoid::Document)
  end

  def is_sequel?(object)
    defined?(::Sequel) && object.class < ::Sequel::Model
  end

  def is_active_record?(object)
    !is_mongoid?(object) && !is_sequel?(object)
  end
end
