app_path = "/home/huginn/current"

worker_processes 2
preload_app true
timeout 180
listen '/home/huginn/shared/tmp/sockets/unicorn.sock'

working_directory app_path

rails_env = ENV['RAILS_ENV'] || 'production'

# Log everything to one file
stderr_path "log/unicorn_out.log"
stdout_path "log/unicorn_err.log"

# Set master PID location
pid '/home/huginn/shared/tmp/pids/unicorn.pid'

before_fork do |server, worker|
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.connection.disconnect!
  old_pid = "#{server.config[:pid]}.oldbin"
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
end

after_fork do |server, worker|
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection
end
