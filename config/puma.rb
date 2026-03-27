# Puma configuration for Huginn
#
# Puma is required for ActionController::Live SSE streaming (used by Remix).
# Unicorn is single-threaded/forking and cannot hold open SSE connections
# without blocking all other requests.
#
# Environment variables:
#   WEB_CONCURRENCY - number of worker processes (default: 2)
#   RAILS_MAX_THREADS - threads per worker (default: 5)
#   PORT - listen port (default: 3000)
#   RAILS_ENV - environment (default: development)

# Thread pool: min..max threads per worker
max_threads_count = Integer(ENV.fetch('RAILS_MAX_THREADS', 5))
min_threads_count = Integer(ENV.fetch('RAILS_MIN_THREADS', max_threads_count))
threads min_threads_count, max_threads_count

# Bind address: supports both TCP port and unix socket.
# Set BIND_UNIX_SOCKET=1 for nginx deployments (matches deployment/nginx configs).
if ENV['BIND_UNIX_SOCKET']
  bind "unix://#{ENV.fetch('PUMA_SOCKET', 'tmp/sockets/puma.socket')}"
else
  port ENV.fetch('PORT', 3000)
end

# Environment
environment ENV.fetch('RAILS_ENV', 'development')

# Workers (forked processes). In production, use multiple workers for
# better CPU utilisation. Each worker gets its own thread pool.
# In development, 0 workers means single-process mode (easier debugging).
workers_count = Integer(ENV.fetch('WEB_CONCURRENCY', 2))
if ENV.fetch('RAILS_ENV', 'development') == 'development'
  workers_count = 0  # single process in dev for easier debugging
end
workers workers_count

# Preload the application for faster worker boot and copy-on-write memory savings.
preload_app! if workers_count > 0

# Worker boot hook: re-establish DB connections after fork
on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# Allow puma to be restarted by `rails restart` command
plugin :tmp_restart
