module Remix
  module Skills
    class EventAnalysisSkill < BaseSkill
      def self.name = 'event_analysis'
      def self.description = 'Help with debugging and analyzing events'

      def self.triggers
        ['debug', 'error', 'not working', 'analyze events', 'why is',
         'what happened', 'trace', 'investigate', 'fix', 'broken',
         'events', 'troubleshoot']
      end

      def self.context(user)
        <<~CONTEXT
          ## Event Analysis & Debugging Guide

          ### Debugging Steps
          1. **Check Recent Errors**: Use `get_recent_errors` to see what's failing
          2. **Search Events**: Use `search_events` to find events from the suspected agent
          3. **Analyze Event Flow**: Use `analyze_event_flow` to trace how events propagate
          4. **Test Configuration**: Use `dry_run_agent` to test without persisting

          ### Common Issues and Solutions

          #### Agent Shows "Not Working"
          - **Cause**: Agent hasn't run recently or produced events
          - **Fix**: Check schedule, enable the agent, verify sources are sending events
          - **Tool**: Use `get_agent` to check last_check_at and last_event_at

          #### Events Not Propagating
          - **Cause**: Missing links between agents
          - **Fix**: Use `connect_agents` to create event flow links
          - **Tool**: Use `get_flow_diagram` to visualize connections

          #### Liquid Template Errors
          - **Cause**: Typos in `{{variable}}` syntax or accessing non-existent fields
          - **Fix**: Check event structure with `search_events`, verify field paths
          - **Example**: `{{event.payload.data.price}}` must match exact payload structure

          #### Empty or Missing Events
          - **Cause**: Source data changed, selectors no longer match
          - **Fix**: Use `dry_run_agent` to test, update CSS selectors or XPath
          - **Tool**: Check agent options with `get_agent`

          #### Agent Continuously Fails
          - **Cause**: External API down, authentication issues, rate limiting
          - **Fix**: Check error messages, verify credentials, adjust schedule
          - **Tool**: Use `get_recent_errors` with agent_id filter

          ### Event Search Tips
          - Use `payload_contains` to search event content by keyword
          - Filter by time range with `since` and `until` parameters
          - Trace backwards: find an event, then check its source agent
          - Look for patterns in error timing (e.g., daily at same time = rate limit)

          ### Debugging Workflow
          1. Identify the problem (agent not working, no events, errors)
          2. Check recent errors for that agent
          3. Examine recent events from source agents
          4. Verify agent connections in flow diagram
          5. Test agent configuration with dry run
          6. Make necessary fixes to options or connections
          7. Re-enable agent and monitor
        CONTEXT
      end
    end
  end
end
