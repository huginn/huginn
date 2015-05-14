#!/usr/bin/env ruby

# This process is used by TwitterStreamAgents to watch the Twitter stream in real time.  It periodically checks for
# new or changed TwitterStreamAgents and starts to follow the stream for them.  It is typically run by foreman via
# the included Procfile.

require_relative './pre_runner_boot'

AgentRunner.new(only: Agents::TwitterStreamAgent).run