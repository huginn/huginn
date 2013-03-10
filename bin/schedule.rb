#!/usr/bin/env ruby

unless defined?(Rails)
  puts
  puts "Please run me with rails runner, for example:"
  puts "  RAILS_ENV=production bundle exec rails runner bin/schedule.rb"
  puts
  exit 1
end

require 'rufus/scheduler'

def run_schedule(time, mutex)
  mutex.synchronize do
    puts "Queuing schedule for #{time}"
    Agent.delay.run_schedule(time)
  end
end

def propogate!(mutex)
  mutex.synchronize do
    puts "Queuing event propagation"
    Agent.delay.receive!
  end
end

mutex = Mutex.new

scheduler = Rufus::Scheduler.start_new

# Schedule event propagation.

scheduler.every '5m' do
  propogate!(mutex)
end

# Schedule repeating events.

%w[2m 5m 10m 30m 1h 2h 5h 12h 1d 2d 7d].each do |schedule|
  scheduler.every schedule do
    run_schedule "every_#{schedule}", mutex
  end
end

# Schedule events for specific times.

# Times are assumed to be in PST for now.  Can store a user#timezone later.
24.times do |hour|
  scheduler.cron "0 #{hour} * * * America/Los_Angeles" do
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

scheduler.join