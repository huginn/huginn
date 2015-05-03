#!/usr/bin/env ruby

# This process is used to maintain Huginn's upkeep behavior, automatically running scheduled Agents and
# periodically propagating and expiring Events. It also running TwitterStreamAgents and Agents that support long running
# background jobs.

Dotenv.load if Rails.env == 'development'

require 'agent_runner'

unless defined?(Rails)
  puts
  puts "Please run me with rails runner, for example:"
  puts "  RAILS_ENV=production bundle exec rails runner bin/agent_runner.rb"
  puts
  exit 1
end

AgentRunner.new(except: DelayedJobWorker).run