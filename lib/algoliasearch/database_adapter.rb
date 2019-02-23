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

  def mark_must_reindex(object)
    determine_instance(object)
    adapter.mark_must_reindex(object)
  end

  ## Find in batches on the ORM klass
  #
  # @param klass [Class] The ORM Class
  # @param batch_size [Integer] Number of records to fetch per batch
  # @param &block [Proc] Block to evaluate in the ORM context
  def find_in_batches(klass, batch_size, &block)
    determine_class(klass)
    adapter.find_in_batches(klass, batch_size, &block)
  end

  def prepare_for_auto_index(klass)
    determine_class(klass)
    adapter.prepare_for_auto_index(klass)
  end

  def prepare_for_auto_remove(klass)
    determine_class(klass)
    adapter.prepare_for_auto_remove(klass)
  end

  def prepare_for_synchronous(klass)
    determine_class(klass)
    adapter.prepare_for_synchronous(klass)
  end

  ## Determine the correct changed method to send to the ORM class
  #
  # This method is not ORM specific so isn't forwared to the
  # ORM adapter
  def attribute_changed_method(attr)
    if defined?(::ActiveRecord) && ::ActiveRecord::VERSION::MAJOR >= 5 && ::ActiveRecord::VERSION::MINOR >= 1 ||
      (defined?(::ActiveRecord) && ::ActiveRecord::VERSION::MAJOR > 5)
      "will_save_change_to_#{attr}?"
    else
      "#{attr}_changed?"
    end
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

  # Return the database adapter instance (default active_record)
  def adapter
    return @adapter if @adapter
    self.adapter = :active_record
    @adapter
  end

  ## Set the database adapter
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

  def is_mongoid_class?(klass)
    !is_sequel_class?(klass) && !is_active_record_class?(klass)
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
