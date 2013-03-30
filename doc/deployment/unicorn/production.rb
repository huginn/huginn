app_path = ENV['OPENSHIFT_REPO_DIR'];

worker_processes 2
preload_app true
timeout 180
listen ENV['OPENSHIFT_TMP_DIR'] + 'unicorn.socket'

working_directory app_path

rails_env = ENV['RAILS_ENV'] || 'production'

# Log everything to one file
stderr_path ENV['OPENSHIFT_REPO_DIR'] + "log/unicorn.log"
stdout_path ENV['OPENSHIFT_REPO_DIR'] + "log/unicorn.log"

# Set master PID location
pid ENV['OPENSHIFT_TMP_DIR'] + 'unicorn.pid'

before_fork do |server, worker|
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
  ActiveRecord::Base.establish_connection
end
