require "net/http"

worker_processes Integer(ENV["WEB_CONCURRENCY"] || 2)
timeout 15
preload_app true

# Note that this will only work correctly when running Heroku with ONE web worker.
# If you want to run more than one, use the standard Huginn Procfile instead, with separate web and job entries.
# You'll need to set the Heroku config variable PROCFILE_PATH to 'Procfile'.
Thread.new do
  worker_pid = nil
  while true
    if worker_pid.nil?
      worker_pid = spawn("bundle exec rails runner bin/threaded.rb")
      puts "New threaded worker PID: #{worker_pid}"
    end

    sleep 45

    begin
      Process.getpgid worker_pid
    rescue Errno::ESRCH
      # No longer running
      worker_pid = nil
    end
  end
end

before_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end

  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.connection.disconnect!
end

after_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT'
  end

  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection
end
