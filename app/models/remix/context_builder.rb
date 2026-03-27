module Remix
  class ContextBuilder
    include DotHelper

    def initialize(user)
      @user = user
    end

    def build
      <<~CONTEXT
        #{role_description}

        #{agent_types_section}

        #{current_agents_section}

        #{current_scenarios_section}

        #{flow_diagram_section}

        #{recent_errors_section}

        #{instructions_section}
      CONTEXT
    end

    private

    def role_description
      <<~MD
        # You are Remix

        You are an AI assistant for Huginn, a system for building agents that perform 
        automated tasks. You help users create, modify, and debug their automation workflows.

        You have access to tools that can create and modify agents, scenarios, and analyze events.
        Always explain what you're doing and why. When making changes, describe the result.
      MD
    end

    def agent_types_section
      types = Agent.types.map do |type|
        begin
          # Create agent with user context to avoid URL generation errors
          agent = type.new(user: @user)
          description = agent.description || ""
          first_line = description.lines.first&.strip || type.name.demodulize.titleize
          "### #{type.name.demodulize.titleize}\n#{first_line}"
        rescue => e
          # Fallback if agent can't be instantiated
          "### #{type.name.demodulize.titleize}\n#{type.name.demodulize.titleize} agent"
        end
      end

      "## Available Agent Types\n\n#{types.join("\n\n")}"
    end

    def current_agents_section
      agents = @user.agents.includes(:scenarios, :sources, :receivers)

      list = agents.limit(50).map do |a|
        status = a.working? ? '✓' : '✗'
        "- [#{status}] **#{a.name}** (#{a.type.demodulize}) - #{a.schedule || 'manual'}"
      end

      count_msg = agents.count > 50 ? " (showing first 50 of #{agents.count})" : ""
      "## Your Current Agents#{count_msg}\n\n#{list.join("\n")}"
    end

    def current_scenarios_section
      scenarios = @user.scenarios.includes(:agents)

      list = scenarios.map do |s|
        "- **#{s.name}**: #{s.agents.count} agents"
      end

      return "## Your Scenarios\n\nNo scenarios yet." if list.empty?

      "## Your Scenarios (#{scenarios.count})\n\n#{list.join("\n")}"
    end

    def flow_diagram_section
      agents = @user.agents.includes(:receivers, :control_targets).limit(100)
      
      return "## Current Flow Diagram\n\nNo agents yet." if agents.empty?

      dot = agents_dot(agents, rich: false)

      "## Current Flow Diagram\n\n```dot\n#{dot}\n```"
    rescue => e
      "## Current Flow Diagram\n\nError generating diagram: #{e.message}"
    end

    def recent_errors_section
      logs = @user.agents
                  .joins(:logs)
                  .where('agent_logs.level >= 4')
                  .where('agent_logs.created_at > ?', 24.hours.ago)
                  .select('agents.name, agent_logs.message, agent_logs.created_at')
                  .limit(10)

      if logs.any?
        list = logs.map { |l| "- #{l.name}: #{l.message}" }
        "## Recent Errors (24h)\n\n#{list.join("\n")}"
      else
        "## Recent Errors\n\nNo errors in the last 24 hours."
      end
    rescue => e
      "## Recent Errors\n\nError fetching logs: #{e.message}"
    end

    def instructions_section
      <<~MD
        ## Guidelines

        1. When creating agents, always specify the full type name (e.g., "Agents::WebsiteAgent")
        2. Use Liquid templates for dynamic values: `{{event.payload.field}}`
        3. When connecting agents, the source emits events that the receiver processes
        4. Control links allow agents to enable/disable other agents
        5. Always test with dry_run before enabling agents when possible
        6. For destructive operations, I will ask for confirmation through the UI
      MD
    end
  end
end
