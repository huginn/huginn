worker_processes 4
timeout 30
preload_app true

before_fork do |server, worker|
  if defined?(ActiveRecord::Base)
      ActiveRecord::Base.connection.disconnect!
      Rails.logger.info('Disconnected from ActiveRecord')
  end
end

after_fork do |server,worker|
  if defined?(ActiveRecord::Base)
    database_url = ENV['DATABASE_URL']
      pool_size = 25
      if(database_url)
         ENV['DATABASE_URL'] = "#{database_url}?pool=#{pool_size}"
         Rails.logger.info("Setting connection pool to #{pool_size}")
      end

      ActiveRecord::Base.establish_connection
      Rails.logger.info('Connected to ActiveRecord')
  end
end