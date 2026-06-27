module Remix
  module Tools
    class GetFlowDiagram < BaseTool
      include DotHelper

      def self.tool_name = 'get_flow_diagram'
      def self.description = 'Get current flow diagram in DOT format or as description'
      def self.parameters
        {
          type: 'object',
          properties: {
            scenario_id: { type: 'integer', description: 'Filter by scenario ID' },
            format: { 
              type: 'string', 
              enum: %w[dot description],
              description: 'Output format: dot (Graphviz) or description (human-readable)' 
            }
          }
        }
      end

      def execute(params)
        agents = if params['scenario_id']
          scenario = user.scenarios.find_by(id: params['scenario_id'])
          return error_response('Scenario not found') unless scenario
          scenario.agents
        else
          user.agents
        end

        agents = agents.includes(:receivers, :control_targets)

        format = params['format'] || 'description'

        if format == 'dot'
          dot = agents_dot(agents, rich: false)
          success_response("Flow diagram in DOT format", diagram: dot)
        else
          description = describe_flow(agents)
          success_response("Flow diagram description", description: description)
        end
      rescue => e
        error_response("Failed to generate diagram: #{e.message}")
      end

      private

      def describe_flow(agents)
        return "No agents in the flow." if agents.empty?

        lines = []
        
        agents.each do |agent|
          status = agent.working? ? '✓' : '✗'
          lines << "\n**#{agent.name}** (#{agent.type.demodulize}) [#{status}]"
          
          if agent.sources.any?
            lines << "  ← Receives from: #{agent.sources.map(&:name).join(', ')}"
          end
          
          if agent.receivers.any?
            lines << "  → Sends to: #{agent.receivers.map(&:name).join(', ')}"
          end
          
          if agent.control_targets.any?
            lines << "  ⚡ Controls: #{agent.control_targets.map(&:name).join(', ')}"
          end
          
          if agent.controllers.any?
            lines << "  ⚡ Controlled by: #{agent.controllers.map(&:name).join(', ')}"
          end
        end

        lines.join("\n")
      end
    end

    class AnalyzeFlow < BaseTool
      def self.tool_name = 'analyze_flow'
      def self.description = 'Analyze flow for potential issues'
      def self.parameters
        {
          type: 'object',
          properties: {
            scenario_id: { type: 'integer', description: 'Filter by scenario ID' }
          }
        }
      end

      def execute(params)
        agents = if params['scenario_id']
          scenario = user.scenarios.find_by(id: params['scenario_id'])
          return error_response('Scenario not found') unless scenario
          scenario.agents
        else
          user.agents
        end

        agents = agents.includes(:sources, :receivers, :control_targets, :controllers)

        issues = []
        
        # Find isolated agents
        agents.each do |agent|
          if agent.sources.empty? && agent.receivers.empty? && 
             agent.controllers.empty? && agent.control_targets.empty?
            issues << {
              type: 'isolated_agent',
              severity: 'warning',
              agent_name: agent.name,
              message: "'#{agent.name}' is not connected to any other agents"
            }
          end
        end

        # Find agents that can't receive but have sources
        agents.each do |agent|
          if !agent.can_receive_events? && agent.sources.any?
            issues << {
              type: 'invalid_receiver',
              severity: 'error',
              agent_name: agent.name,
              message: "'#{agent.name}' cannot receive events but has #{agent.sources.count} source(s)"
            }
          end
        end

        # Find agents that can't create but have receivers
        agents.each do |agent|
          if !agent.can_create_events? && agent.receivers.any?
            issues << {
              type: 'invalid_source',
              severity: 'error',
              agent_name: agent.name,
              message: "'#{agent.name}' cannot create events but has #{agent.receivers.count} receiver(s)"
            }
          end
        end

        # Find disabled agents with receivers
        agents.each do |agent|
          if agent.disabled && agent.receivers.any?
            issues << {
              type: 'disabled_source',
              severity: 'warning',
              agent_name: agent.name,
              message: "'#{agent.name}' is disabled but has #{agent.receivers.count} receiver(s) waiting for events"
            }
          end
        end

        # Find agents that aren't working
        agents.each do |agent|
          if !agent.working? && !agent.disabled
            issues << {
              type: 'not_working',
              severity: 'error',
              agent_name: agent.name,
              message: "'#{agent.name}' is not working (may need attention)"
            }
          end
        end

        if issues.empty?
          success_response("No issues found in the flow", issues: [])
        else
          success_response("Found #{issues.count} potential issues", issues: issues)
        end
      end
    end
  end
end
