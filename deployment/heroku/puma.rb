app_dir = File.expand_path("../..", __dir__)
environment_name = ENV.fetch("RAILS_ENV", "production")
threaded_worker_command = %w[bundle exec rails runner bin/threaded.rb]
threaded_worker_env = { "RAILS_ENV" => environment_name }
threaded_worker_pid = nil
threaded_worker_monitor = nil

shutdown_threaded_worker = lambda do
  next unless threaded_worker_pid

  begin
    Process.kill("TERM", threaded_worker_pid)
  rescue Errno::ESRCH
  end

  begin
    Process.wait(threaded_worker_pid)
  rescue Errno::ECHILD, Errno::ESRCH
  end

  threaded_worker_pid = nil
end

directory app_dir
environment environment_name
threads 1, 1
bind "tcp://0.0.0.0:#{ENV.fetch("PORT", 3000)}"
worker_timeout 15

# Note that this will only work correctly when running Heroku with ONE web worker.
# If you want to run more than one, use the standard Huginn Procfile instead, with separate web and job entries.
# You'll need to set the Heroku config variable PROCFILE_PATH to 'Procfile'.
on_booted do
  next if threaded_worker_monitor&.alive?

  threaded_worker_monitor = Thread.new do
    loop do
      if threaded_worker_pid
        begin
          waited_pid = Process.wait(threaded_worker_pid, Process::WNOHANG)
          threaded_worker_pid = nil if waited_pid
        rescue Errno::ECHILD, Errno::ESRCH
          threaded_worker_pid = nil
        end
      end

      unless threaded_worker_pid
        threaded_worker_pid = spawn(threaded_worker_env, *threaded_worker_command, chdir: app_dir)
        puts "New threaded worker PID: #{threaded_worker_pid}"
      end

      sleep 45
    end
  end

  threaded_worker_monitor.abort_on_exception = true
end

on_restart { shutdown_threaded_worker.call }
at_exit { shutdown_threaded_worker.call }
