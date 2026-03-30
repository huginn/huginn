require "active_support/core_ext/object/blank"
require "fileutils"

app_dir = File.expand_path("..", __dir__)
environment_name = ENV.fetch("RAILS_ENV", "development")
socket_path = File.join(app_dir, "tmp/sockets/puma.sock")

FileUtils.mkdir_p([
  File.join(app_dir, "tmp/pids"),
  File.join(app_dir, "tmp/sockets")
])

directory app_dir
environment environment_name
pidfile File.join(app_dir, "tmp/pids/puma.pid")
state_path File.join(app_dir, "tmp/pids/puma.state")

if ENV["RAILS_LOG_TO_STDOUT"].blank?
  FileUtils.mkdir_p(File.join(app_dir, "log"))
  stdout_redirect File.join(app_dir, "log/stdout.log"), File.join(app_dir, "log/stderr.log"), true
end

# Keep Puma single-threaded unless thread safety has been audited.
threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", 1))
threads threads_count, threads_count

if environment_name == "production" && ENV["IP"].blank? && ENV["PORT"].blank?
  bind "unix://#{socket_path}?umask=0111"
else
  bind "tcp://#{ENV.fetch("IP", "0.0.0.0")}:#{ENV.fetch("PORT", 3000)}"
end

case workers_count = Integer(ENV.fetch("WEB_CONCURRENCY", 2))
when (2..)
  workers workers_count
  worker_timeout 180

  if (fork_worker_after_requests = ENV["PUMA_FORK_WORKER_AFTER_REQUESTS"].presence&.to_i)
    fork_worker fork_worker_after_requests

    on_refork do
      ActiveRecord::Base.connection_handler.clear_all_connections!
    end
  end

  before_fork do
    ActiveRecord::Base.connection_handler.clear_all_connections!
  end

  before_worker_boot do
    ActiveRecord::Base.establish_connection
  end
end

plugin :tmp_restart
