# this class wraps an Algolia::Index object ensuring all raised exceptions
# are correctly logged or thrown depending on the `raise_on_failure` option
module AlgoliaSearch
  class SafeIndex

    def initialize(name, raise_on_failure)
      @index = ::Algolia::Index.new(name)
      @raise_on_failure = raise_on_failure.nil? || raise_on_failure
    end

    ::Algolia::Index.instance_methods(false).each do |m|
      define_method(m) do |*args, &block|
        SafeIndex.log_or_throw(m, @raise_on_failure) do
          @index.send(m, *args, &block)
        end
      end
    end

    # special handling of wait_task to handle null task_id
    def wait_task(task_id)
      return if task_id.nil? && !@raise_on_failure # ok
      SafeIndex.log_or_throw(:wait_task, @raise_on_failure) do
        @index.wait_task(task_id)
      end
    end

    # special handling of get_settings to avoid raising errors on 404
    def get_settings(*args)
      SafeIndex.log_or_throw(:get_settings, @raise_on_failure) do
        begin
          @index.get_settings(*args)
        rescue Algolia::AlgoliaError => e
          return {} if e.code == 404 # not fatal
          raise e
        end
      end
    end

    # expose move as well
    def self.move_index(old_name, new_name)
      SafeIndex.log_or_throw(:move_index, true) do
        ::Algolia.move_index(old_name, new_name)
      end
    end

    private

    def self.log_or_throw(method, raise_on_failure, &block)
      begin
        yield
      rescue Algolia::AlgoliaError => e
        raise e if raise_on_failure
        # log the error
        (Rails.logger || Logger.new(STDOUT)).error("[algoliasearch-rails] #{e.message}")
        # return something
        case method.to_s
        when 'search'
          # some attributes are required
          { 'hits' => [], 'hitsPerPage' => 0, 'page' => 0, 'facets' => {}, 'error' => e }
        else
          # empty answer
          { 'error' => e }
        end
      end
    end

  end
end
