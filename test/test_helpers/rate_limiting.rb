module RateLimiting
  def counting_rate_limits
    store = ApplicationController.cache_store
    counter = ActiveSupport::Cache::MemoryStore.new
    store.define_singleton_method(:increment) { |*args, **options| counter.increment(*args, **options) }
    yield
  ensure
    store.singleton_class.remove_method(:increment)
  end
end
