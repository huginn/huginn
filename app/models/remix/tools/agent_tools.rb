module Remix
  module Tools
    class ListAgents < BaseTool
      def self.tool_name = 'list_agents'
      def self.description = 'List all agents for the current user with optional filtering'
      def self.parameters
        {
          type: 'object',
          properties: {
            scenario_id: { type: 'integer', description: 'Filter by scenario ID' },
            type: { type: 'string', description: 'Filter by agent type (e.g., Agents::WebsiteAgent)' },
            status: { type: 'string', enum: %w[working not_working disabled all], description: 'Filter by status' }
          }
        }
      end

      def execute(params)
        agents = user.agents.includes(:scenarios, :sources, :receivers)
        
        if params['scenario_id']
          agents = agents.joins(:scenarios).where(scenarios: { id: params['scenario_id'] })
        end
        
        agents = agents.where(type: params['type']) if params['type']
        
        case params['status']
        when 'disabled'
          agents = agents.where(disabled: true)
        end

        result = agents.map do |a|
          {
            id: a.id,
            name: a.name,
            type: a.type,
            schedule: a.schedule,
            disabled: a.disabled,
            working: a.working?,
            sources: a.sources.pluck(:name),
            receivers: a.receivers.pluck(:name),
            scenarios: a.scenarios.pluck(:name),
            last_check_at: a.last_check_at,
            last_event_at: a.last_event_at
          }
        end

        # Post-filter for working status (can't do in DB query)
        case params['status']
        when 'working'
          result = result.select { |a| a[:working] }
        when 'not_working'
          result = result.reject { |a| a[:working] }
        end

        success_response("Found #{result.count} agents", agents: result)
      end
    end

    class GetAgent < BaseTool
      def self.tool_name = 'get_agent'
      def self.description = 'Get detailed configuration for a specific agent'
      def self.parameters
        {
          type: 'object',
          properties: {
            agent_id: { type: 'integer', description: 'ID of the agent' },
            agent_name: { type: 'string', description: 'Name of the agent (alternative to agent_id)' }
          }
        }
      end

      def execute(params)
        agent = if params['agent_id']
          user.agents.find_by(id: params['agent_id'])
        elsif params['agent_name']
          user.agents.find_by(name: params['agent_name'])
        end

        return error_response('Agent not found') unless agent

        success_response("Agent details for '#{agent.name}'", {
          id: agent.id,
          name: agent.name,
          type: agent.type,
          options: agent.options,
          schedule: agent.schedule,
          disabled: agent.disabled,
          keep_events_for: agent.keep_events_for,
          propagate_immediately: agent.propagate_immediately,
          memory: agent.memory,
          working: agent.working?,
          sources: agent.sources.map { |s| { id: s.id, name: s.name } },
          receivers: agent.receivers.map { |r| { id: r.id, name: r.name } },
          scenarios: agent.scenarios.map { |s| { id: s.id, name: s.name } },
          last_check_at: agent.last_check_at,
          last_event_at: agent.last_event_at,
          last_receive_at: agent.last_receive_at,
          events_count: agent.events.count
        })
      end
    end

    class CreateAgent < BaseTool
      def self.tool_name = 'create_agent'
      def self.description = 'Create a new agent'
      def self.parameters
        {
          type: 'object',
          properties: {
            type: { type: 'string', description: 'Agent type (e.g., Agents::WebsiteAgent)' },
            name: { type: 'string', description: 'Display name for the agent' },
            options: { type: 'object', description: 'Agent-specific configuration options' },
            schedule: { type: 'string', description: 'Cron-like schedule (e.g., every_1h, midnight)' },
            scenario_id: { type: 'integer', description: 'Add to this scenario' },
            disabled: { type: 'boolean', description: 'Create as disabled' }
          },
          required: %w[type name options]
        }
      end

      def execute(params)
        agent = Agent.build_for_type(params['type'], user, {
          name: params['name'],
          options: params['options'],
          schedule: params['schedule'],
          disabled: params['disabled'] || false
        })

        if agent.save
          if params['scenario_id']
            scenario = user.scenarios.find_by(id: params['scenario_id'])
            scenario.agents << agent if scenario
          end

          success_response("Created agent '#{agent.name}'", agent_id: agent.id, name: agent.name)
        else
          error_response("Failed to create agent", agent.errors.full_messages)
        end
      end
    end

    class UpdateAgent < BaseTool
      def self.tool_name = 'update_agent'
      def self.description = 'Update an existing agent'
      def self.parameters
        {
          type: 'object',
          properties: {
            agent_id: { type: 'integer', description: 'ID of agent to update' },
            name: { type: 'string', description: 'New name' },
            options: { type: 'object', description: 'New options' },
            schedule: { type: 'string', description: 'New schedule' },
            disabled: { type: 'boolean', description: 'Enable/disable agent' },
            memory: { type: 'object', description: 'Update agent memory' }
          },
          required: %w[agent_id]
        }
      end

      def execute(params)
        agent = user.agents.find_by(id: params['agent_id'])
        return error_response('Agent not found') unless agent

        updates = {}
        updates[:name] = params['name'] if params.key?('name')
        updates[:options] = params['options'] if params.key?('options')
        updates[:schedule] = params['schedule'] if params.key?('schedule')
        updates[:disabled] = params['disabled'] if params.key?('disabled')
        updates[:memory] = params['memory'] if params.key?('memory')

        if agent.update(updates)
          success_response("Updated agent '#{agent.name}'")
        else
          error_response("Failed to update agent", agent.errors.full_messages)
        end
      end
    end

    class DeleteAgent < BaseTool
      def self.tool_name = 'delete_agent'
      def self.description = 'Delete an agent (requires confirmation)'
      def self.parameters
        {
          type: 'object',
          properties: {
            agent_id: { type: 'integer', description: 'ID of agent to delete' }
          },
          required: %w[agent_id]
        }
      end

      def requires_confirmation?
        true
      end

      def confirmation_message(params)
        agent = user.agents.find_by(id: params['agent_id'])
        return "Agent not found" unless agent
        "Delete agent '#{agent.name}'? This will also delete #{agent.events.count} events."
      end

      def execute(params)
        agent = user.agents.find_by(id: params['agent_id'])
        return error_response('Agent not found') unless agent

        name = agent.name
        agent.destroy!
        success_response("Deleted agent '#{name}'")
      end
    end

    class DryRunAgent < BaseTool
      def self.tool_name = 'dry_run_agent'
      def self.description = 'Test an agent without persisting results'
      def self.parameters
        {
          type: 'object',
          properties: {
            agent_id: { type: 'integer', description: 'ID of agent to test' },
            event: { type: 'object', description: 'Optional test event payload for agents that receive events' }
          },
          required: %w[agent_id]
        }
      end

      def execute(params)
        agent = user.agents.find_by(id: params['agent_id'])
        return error_response('Agent not found') unless agent
        return error_response('Agent does not support dry run') unless agent.can_dry_run?

        if params['event'] && agent.can_receive_events?
          test_event = Event.new(
            user: user,
            agent: agent,
            payload: params['event']
          )
          results = agent.dry_run!([test_event])
        else
          results = agent.dry_run!
        end

        success_response("Dry run completed", results: results)
      rescue => e
        error_response("Dry run failed: #{e.message}")
      end
    end

    class GetAgentMemory < BaseTool
      def self.tool_name = 'get_agent_memory'
      def self.description = 'Retrieve agent memory state'
      def self.parameters
        {
          type: 'object',
          properties: {
            agent_id: { type: 'integer', description: 'ID of the agent' }
          },
          required: %w[agent_id]
        }
      end

      def execute(params)
        agent = user.agents.find_by(id: params['agent_id'])
        return error_response('Agent not found') unless agent

        success_response("Memory for '#{agent.name}'", memory: agent.memory || {})
      end
    end

    class UpdateAgentMemory < BaseTool
      def self.tool_name = 'update_agent_memory'
      def self.description = 'Modify agent memory'
      def self.parameters
        {
          type: 'object',
          properties: {
            agent_id: { type: 'integer', description: 'ID of the agent' },
            memory: { type: 'object', description: 'New memory data' }
          },
          required: %w[agent_id memory]
        }
      end

      def execute(params)
        agent = user.agents.find_by(id: params['agent_id'])
        return error_response('Agent not found') unless agent

        if agent.update(memory: params['memory'])
          success_response("Updated memory for '#{agent.name}'")
        else
          error_response("Failed to update memory", agent.errors.full_messages)
        end
      end
    end
  end
end
