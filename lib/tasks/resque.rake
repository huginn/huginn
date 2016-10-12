if Rails.configuration.active_job.queue_adapter == :resque
  task "resque:setup" => :environment do
    ENV['QUEUE'] = '*'
    ENV['TERM_CHILD'] = '1'
    ENV['INTERVAL'] = '0.5'
    ENV['RUN_AT_EXIT_HOOKS'] = 'yes' if Rails.env == 'development'
  end
  require 'resque/tasks'
end
