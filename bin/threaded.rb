#!/usr/bin/env ruby

require_relative './pre_runner_boot'

except = []
except << DelayedJobWorker if Rails.configuration.active_job.queue_adapter != :delayed_job
agent_runner = AgentRunner.new(except: except)

# We need to wait a bit to let delayed_job set it's traps so we can override them
Thread.new do
  sleep 5
  agent_runner.set_traps
end

agent_runner.run
