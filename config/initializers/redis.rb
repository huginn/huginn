# frozen_string_literal: true

Redis.current = Redis.new(url: ENV['REDIS_URL'] || 'redis://127.0.0.1:6379')
