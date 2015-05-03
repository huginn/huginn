#!/usr/bin/env ruby

Dotenv.load if Rails.env == 'development'

require 'agent_runner'

unless defined?(Rails)
  puts
  puts "Please run me with rails runner, for example:"
  puts "  RAILS_ENV=production bundle exec rails runner bin/threaded.rb"
  puts
  exit 1
end

agent_runner = AgentRunner.new

# We need to wait a bit to let delayed_job set it's traps so we can override them
Thread.new do
  sleep 5
  agent_runner.set_traps
end

agent_runner.run
