#!/usr/bin/env ruby

require_relative './pre_runner_boot'

agent_runner = AgentRunner.new

# We need to wait a bit to let delayed_job set it's traps so we can override them
Thread.new do
  sleep 5
  agent_runner.set_traps
end

agent_runner.run
