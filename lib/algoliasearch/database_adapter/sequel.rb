module DatabaseAdapter
  module Sequel
    extend self

    def get_default_attributes(object)
      object.to_hash
    end

    def get_attributes(attributes, object)
      DatabaseAdapter.attributes_to_hash(attributes, object)
    end

    def find_in_batches(klass, batch_size, &block)
      klass.dataset.extension(:pagination).each_page(batch_size, &block)
    end

    def prepare_for_auto_index(klass)
      klass.class_eval do
        copy_after_validation = instance_method(:after_validation)
        copy_before_save = instance_method(:before_save)

        define_method(:after_validation) do |*args|
          super(*args)
          copy_after_validation.bind(self).call
          algolia_mark_must_reindex
        end

        define_method(:before_save) do |*args|
          copy_before_save.bind(self).call
          algolia_mark_for_auto_indexing
          super(*args)
        end

        sequel_version = Gem::Version.new(::Sequel.version)
        if sequel_version >= Gem::Version.new('4.0.0') && sequel_version < Gem::Version.new('5.0.0')
          copy_after_commit = instance_method(:after_commit)
          define_method(:after_commit) do |*args|
            super(*args)
            copy_after_commit.bind(self).call
            algolia_perform_index_tasks
          end
        else
          copy_after_save = instance_method(:after_save)
          define_method(:after_save) do |*args|
            super(*args)
            copy_after_save.bind(self).call
            self.db.after_commit do
              algolia_perform_index_tasks
            end
          end
        end
      end
    end

    def prepare_for_auto_remove(klass)
      klass.class_eval do
        copy_after_destroy = instance_method(:after_destroy)

        define_method(:after_destroy) do |*args|
          copy_after_destroy.bind(self).call
          algolia_enqueue_remove_from_index!(algolia_synchronous?)
          super(*args)
        end
      end
    end

    def prepare_for_synchronous(klass)
      klass.class_eval do
        copy_after_validation = instance_method(:after_validation)
        define_method(:after_validation) do |*args|
          super(*args)
          copy_after_validation.bind(self).call
          algolia_mark_synchronous
        end
      end
    end

    def mark_must_reindex(object)
      object.new? || object.class.algolia_must_reindex?(object)
    end

  end
end
