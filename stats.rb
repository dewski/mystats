class Stats
  class << self
    def redis=(redis)
      @redis = Redis::Namespace.new :stats, :redis => redis
    end

    def redis
      @redis
    end

    def measure!(stat, type, action, value)
      redis.sadd type, stat
      redis.send action, value
    end

    def increment(stat, by = 1)
      redis.sadd :counters, stat
      redis.incrby stat, by
    end

    def decrement(stat, by = 1)
      redis.sadd :counters, stat
      redis.decrby stat, by
    end

    def timing(stat, ms)
      redis.sadd :timers, stat
      redis.rpush stat, ms.to_i
    end

    def time(state)
      state   = Time.now
      result  = yield
      timing(stat, ((Time.now - start) * 1000).round)
      result
    end

    def meter(stat, by = 1)
      redis.sadd :meters, stat
      redis.incrby stat, by
    end

    def gauge(stat, value = nil, &block)
      redis.sadd :gauges, stat

      if value
        redis.set stat, value
      else
        gauge_callbacks[stat] = block
      end
    end

    def refresh!(raise_exceptions = false)
      update_gauges!(raise_exceptions)
    end

    def flush!
      keys = meters + histograms + timers

      redis.pipelined do
        keys.each { |k| redis.del k }
      end
    end

    def reset!
      redis.pipelined do
        keys.each { |k| redis.del k }
        [:gauges, :meters, :counters, :histograms, :timers].
          each { |k| redis.del k }
      end
    end

    def to_hash(flush = false)
      hash = {:gauges => {}, :meters => {}, :counters => {}, :histograms => {}, :timers => {}}

      gauges.     each { |g| hash[:gauges][g]     = redis.get g }
      meters.     each { |m| hash[:meters][m]     = redis.lrange(m, 0, -1) }
      counters.   each { |c| hash[:counters][c]   = redis.get c }
      histograms. each { |h| hash[:histograms][h] = redis.lrange(h, 0, -1) }
      timers.     each { |t| hash[:timers][t]     = redis.lrange(t, 0, -1) }

      flush! if flush

      hash
    end

    protected

    def update_gauges!(raise_exceptions = false)
      gauge_callbacks.each do |(stat, callback)|
        begin
          gauge stat, callback.call
        rescue Exception
          raise if raise_exceptions
        end
      end
    end

    def keys
      gauges + meters + counters + histograms + timers
    end

    def gauges
      redis.smembers(:gauges) || []
    end

    def gauge_callbacks
      @gauge_callbacks ||= {}
    end

    def meters
      redis.smembers(:meters) || []
    end

    def counters
      redis.smembers(:counters) || []
    end

    def histograms
      redis.smembers(:histograms) || []
    end

    def timers
      redis.smembers(:timers) || []
    end
  end
end
