#!/usr/bin/env ruby

# This process is used to maintain Huginn's upkeep behavior, automatically running scheduled Agents and
# periodically propagating and expiring Events.  It's typically run via foreman and the included Procfile.

unless defined?(Rails)
  puts
  puts "Please run me with rails runner, for example:"
  puts "  RAILS_ENV=production bundle exec rails runner bin/schedule.rb"
  puts
  exit 1
end

scheduler = HuginnScheduler.new(frequency: ENV['SCHEDULER_FREQUENCY'].presence || 0.3)
scheduler.run!
