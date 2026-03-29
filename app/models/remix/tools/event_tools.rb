module Remix
  module Tools
    class SearchEvents < BaseTool
      def self.tool_name = 'search_events'
      def self.description = 'Search events with filters'
      def self.parameters
        {
          type: 'object',
          properties: {
            agent_id: { type: 'integer', description: 'Filter by agent ID' },
            payload_contains: { type: 'string', description: 'Search for text in payload' },
            since: { type: 'string', description: 'Events created after this time (ISO8601 format)' },
            until: { type: 'string', description: 'Events created before this time (ISO8601 format)' },
            limit: { type: 'integer', description: 'Maximum number of events to return (default 50)' }
          }
        }
      end

      def execute(params)
        events = user.events.order(created_at: :desc)

        if params['agent_id']
          agent = user.agents.find_by(id: params['agent_id'])
          return error_response('Agent not found') unless agent
          events = events.where(agent: agent)
        end

        if params['since']
          begin
            events = events.where('created_at >= ?', Time.parse(params['since']))
          rescue ArgumentError
            return error_response("Invalid 'since' date format")
          end
        end

        if params['until']
          begin
            events = events.where('created_at <= ?', Time.parse(params['until']))
          rescue ArgumentError
            return error_response("Invalid 'until' date format")
          end
        end

        limit = params['limit'] || 50
        events = events.limit([limit.to_i, 500].min)

        result = events.includes(:agent).map do |e|
          {
            id: e.id,
            agent_name: e.agent.name,
            agent_id: e.agent_id,
            payload: e.payload,
            created_at: e.created_at,
            expires_at: e.expires_at
          }
        end

        # Post-filter for payload contains (since we can't easily query JSON in a DB-agnostic way)
        if params['payload_contains']
          search_term = params['payload_contains'].downcase
          result = result.select do |e|
            e[:payload].to_json.downcase.include?(search_term)
          end
        end

        success_response("Found #{result.count} events", events: result)
      end
    end

    class GetEvent < BaseTool
      def self.tool_name = 'get_event'
      def self.description = 'Get detailed event information'
      def self.parameters
        {
          type: 'object',
          properties: {
            event_id: { type: 'integer', description: 'ID of the event' }
          },
          required: %w[event_id]
        }
      end

      def execute(params)
        event = user.events.includes(:agent).find_by(id: params['event_id'])
        return error_response('Event not found') unless event

        success_response("Event ##{event.id}", {
          id: event.id,
          agent_name: event.agent.name,
          agent_id: event.agent_id,
          agent_type: event.agent.type,
          payload: event.payload,
          created_at: event.created_at,
          expires_at: event.expires_at,
          lat: event.lat,
          lng: event.lng
        })
      end
    end

    class AnalyzeEventFlow < BaseTool
      def self.tool_name = 'analyze_event_flow'
      def self.description = 'Trace event propagation through agents'
      def self.parameters
        {
          type: 'object',
          properties: {
            event_id: { type: 'integer', description: 'ID of the event to trace' }
          },
          required: %w[event_id]
        }
      end

      def execute(params)
        event = user.events.includes(:agent).find_by(id: params['event_id'])
        return error_response('Event not found') unless event

        source_agent = event.agent
        
        # Find which agents received this event (through links)
        receiving_agents = source_agent.receivers.map do |receiver|
          # Check if receiver created events after this event
          subsequent_events = receiver.events.where('created_at > ?', event.created_at).order(:created_at).limit(5)
          
          {
            agent_name: receiver.name,
            agent_id: receiver.id,
            received_at: receiver.last_receive_at,
            subsequent_events_count: subsequent_events.count,
            sample_events: subsequent_events.map { |e| { id: e.id, created_at: e.created_at } }
          }
        end

        success_response("Event flow analysis for event ##{event.id}", {
          source_event: {
            id: event.id,
            agent_name: source_agent.name,
            agent_id: source_agent.id,
            created_at: event.created_at,
            payload: event.payload
          },
          receiving_agents: receiving_agents,
          propagate_immediately: source_agent.propagate_immediately
        })
      end
    end

    class GetRecentErrors < BaseTool
      def self.tool_name = 'get_recent_errors'
      def self.description = 'Get error logs for debugging'
      def self.parameters
        {
          type: 'object',
          properties: {
            agent_id: { type: 'integer', description: 'Filter by agent ID' },
            since: { type: 'string', description: 'Errors since this time (ISO8601 format, default: 24 hours ago)' },
            limit: { type: 'integer', description: 'Maximum number of errors to return (default 50)' }
          }
        }
      end

      def execute(params)
        logs = AgentLog.joins(:agent).where(agents: { user_id: user.id })
        logs = logs.where('level >= 4') # Error level and above
        
        since = if params['since']
          begin
            Time.parse(params['since'])
          rescue ArgumentError
            return error_response("Invalid 'since' date format")
          end
        else
          24.hours.ago
        end
        
        logs = logs.where('agent_logs.created_at > ?', since)
        logs = logs.where(agent_id: params['agent_id']) if params['agent_id']
        
        limit = params['limit'] || 50
        logs = logs.order(created_at: :desc).limit([limit.to_i, 500].min)
        
        result = logs.includes(:agent).map do |log|
          {
            agent_name: log.agent.name,
            agent_id: log.agent_id,
            level: log.level,
            message: log.message,
            created_at: log.created_at
          }
        end

        success_response("Found #{result.count} errors since #{since}", errors: result)
      end
    end

    class ReEmitEvent < BaseTool
      def self.tool_name = 're_emit_event'
      def self.description = 'Re-emit an event for reprocessing'
      def self.parameters
        {
          type: 'object',
          properties: {
            event_id: { type: 'integer', description: 'ID of the event to re-emit' }
          },
          required: %w[event_id]
        }
      end

      def execute(params)
        event = user.events.includes(:agent).find_by(id: params['event_id'])
        return error_response('Event not found') unless event

        # Create a new event with the same payload
        new_event = event.agent.create_event(payload: event.payload)
        
        if new_event.persisted?
          success_response(
            "Re-emitted event from '#{event.agent.name}'",
            new_event_id: new_event.id,
            original_event_id: event.id
          )
        else
          error_response("Failed to re-emit event", new_event.errors.full_messages)
        end
      end
    end
  end
end
