#!/usr/bin/env ruby

# This process is used to maintain Huginn's upkeep behavior, automatically running scheduled Agents and
# periodically propagating and expiring Events.  It's typically run via foreman and the included Procfile.

require_relative './pre_runner_boot'

AgentRunner.new(only: HuginnScheduler).run