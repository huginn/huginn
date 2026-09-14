# frozen_string_literal: true

working_directory Rails.root.to_s
polling_interval Delayed::Worker.sleep_delay
pid_file Rails.root.join("tmp/pids/delayed_job_master.pid").to_s
log_file $stdout
log_level :info

add_worker do |worker|
  worker.max_processes Integer(ENV.fetch("DELAYED_JOB_WORKERS", "1"), 10)
  # delayed_job_master supports threads, but Huginn Agents remain process-isolated.
  worker.max_threads 1
  worker.max_memory Integer(ENV.fetch("DELAYED_JOB_MAX_MEMORY", "512"), 10)
  worker.exit_on_complete true
end

before_fork do |_master, _worker|
  ActiveRecord::Base.connection.disconnect!
end

after_fork do |_master, _worker|
  ActiveRecord::Base.establish_connection
end
