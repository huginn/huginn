#!/usr/bin/env ruby

unless defined?(Rails)
  puts
  puts "Please run me with rails runner, for example:"
  puts "  RAILS_ENV=production bundle exec rails runner bin/schedule.rb"
  puts
  exit 1
end

require 'rufus/scheduler'

class HuginnScheduler
  def run_schedule(time, mutex)
    ActiveRecord::Base.connection_pool.with_connection do
      mutex.synchronize do
        puts "Queuing schedule for #{time}"
        Agent.delay.run_schedule(time)
      end
    end
  end

  def propagate!(mutex)
    ActiveRecord::Base.connection_pool.with_connection do
      mutex.synchronize do
        puts "Queuing event propagation"
        Agent.delay.receive!
      end
    end
  end

  def run!
    mutex = Mutex.new

    rufus_scheduler = Rufus::Scheduler.new

    # Schedule event propagation.

    rufus_scheduler.every '1m' do
      propagate!(mutex)
    end

    # Schedule repeating events.

    %w[2m 5m 10m 30m 1h 2h 5h 12h 1d 2d 7d].each do |schedule|
      rufus_scheduler.every schedule do
        run_schedule "every_#{schedule}", mutex
      end
    end

    # Schedule events for specific times.

    # Times are assumed to be in PST for now.  Can store a user#timezone later.
    24.times do |hour|
      rufus_scheduler.cron "0 #{hour} * * * America/Los_Angeles" do
        if hour == 0
          run_schedule "midnight", mutex
        elsif hour < 12
          run_schedule "#{hour}am", mutex
        elsif hour == 12
          run_schedule "noon", mutex
        else
          run_schedule "#{hour - 12}pm", mutex
        end
      end
    end

    rufus_scheduler.join
  end
end

scheduler = HuginnScheduler.new
scheduler.run!