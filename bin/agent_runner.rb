#!/usr/bin/env ruby

# This process is used to maintain Huginn's upkeep behavior, automatically running scheduled Agents and
# periodically propagating and expiring Events. It also running TwitterStreamAgents and Agents that support long running
# background jobs.

require_relative './pre_runner_boot'

AgentRunner.new(except: DelayedJobWorker).run