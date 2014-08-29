#!/usr/bin/env ruby

# This process is used by TwitterStreamAgents to watch the Twitter stream in real time.  It periodically checks for
# new or changed TwitterStreamAgents and starts to follow the stream for them.  It is typically run by foreman via
# the included Procfile.

unless defined?(Rails)
  puts
  puts "Please run me with rails runner, for example:"
  puts "  RAILS_ENV=production bundle exec rails runner bin/twitter_stream.rb"
  puts
  exit 1
end

TwitterStream.new.run