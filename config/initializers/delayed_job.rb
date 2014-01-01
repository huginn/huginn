Delayed::Worker.destroy_failed_jobs = true
Delayed::Worker.max_attempts = 5
Delayed::Worker.max_run_time = 20.minutes
Delayed::Worker.default_priority = 10
Delayed::Worker.delay_jobs = !Rails.env.test?

Delayed::Worker.logger = Logger.new(Rails.root.join('log', 'delayed_job.log'))
Delayed::Worker.logger.level = Logger::DEBUG
