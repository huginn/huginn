module Remix
  module Tools
    class ListScenarios < BaseTool
      def self.tool_name = 'list_scenarios'
      def self.description = 'List all scenarios'
      def self.parameters
        { type: 'object', properties: {} }
      end

      def execute(params)
        scenarios = user.scenarios.includes(:agents)

        result = scenarios.map do |s|
          {
            id: s.id,
            name: s.name,
            description: s.description,
            agents_count: s.agents.count,
            icon: s.icon,
            tag_fg_color: s.tag_fg_color,
            tag_bg_color: s.tag_bg_color
          }
        end

        success_response("Found #{result.count} scenarios", scenarios: result)
      end
    end

    class GetScenario < BaseTool
      def self.tool_name = 'get_scenario'
      def self.description = 'Get scenario details with agents'
      def self.parameters
        {
          type: 'object',
          properties: {
            scenario_id: { type: 'integer', description: 'ID of the scenario' }
          },
          required: %w[scenario_id]
        }
      end

      def execute(params)
        scenario = user.scenarios.includes(agents: [:sources, :receivers]).find_by(id: params['scenario_id'])
        return error_response('Scenario not found') unless scenario

        success_response("Scenario '#{scenario.name}'", {
          id: scenario.id,
          name: scenario.name,
          description: scenario.description,
          icon: scenario.icon,
          agents: scenario.agents.map { |a| 
            {
              id: a.id,
              name: a.name,
              type: a.type,
              disabled: a.disabled,
              working: a.working?
            }
          }
        })
      end
    end

    class CreateScenario < BaseTool
      def self.tool_name = 'create_scenario'
      def self.description = 'Create a new scenario'
      def self.parameters
        {
          type: 'object',
          properties: {
            name: { type: 'string', description: 'Scenario name' },
            description: { type: 'string', description: 'Description of the scenario' },
            icon: { type: 'string', description: 'Icon name (e.g., star, gear)' }
          },
          required: %w[name]
        }
      end

      def execute(params)
        scenario = user.scenarios.build(
          name: params['name'],
          description: params['description'],
          icon: params['icon']
        )

        if scenario.save
          success_response("Created scenario '#{scenario.name}'", scenario_id: scenario.id)
        else
          error_response("Failed to create scenario", scenario.errors.full_messages)
        end
      end
    end

    class UpdateScenario < BaseTool
      def self.tool_name = 'update_scenario'
      def self.description = 'Update scenario metadata'
      def self.parameters
        {
          type: 'object',
          properties: {
            scenario_id: { type: 'integer', description: 'ID of scenario to update' },
            name: { type: 'string', description: 'New name' },
            description: { type: 'string', description: 'New description' },
            icon: { type: 'string', description: 'New icon' }
          },
          required: %w[scenario_id]
        }
      end

      def execute(params)
        scenario = user.scenarios.find_by(id: params['scenario_id'])
        return error_response('Scenario not found') unless scenario

        updates = {}
        updates[:name] = params['name'] if params.key?('name')
        updates[:description] = params['description'] if params.key?('description')
        updates[:icon] = params['icon'] if params.key?('icon')

        if scenario.update(updates)
          success_response("Updated scenario '#{scenario.name}'")
        else
          error_response("Failed to update scenario", scenario.errors.full_messages)
        end
      end
    end

    class DeleteScenario < BaseTool
      def self.tool_name = 'delete_scenario'
      def self.description = 'Delete a scenario (requires confirmation)'
      def self.parameters
        {
          type: 'object',
          properties: {
            scenario_id: { type: 'integer', description: 'ID of scenario to delete' }
          },
          required: %w[scenario_id]
        }
      end

      def requires_confirmation?
        true
      end

      def confirmation_message(params)
        scenario = user.scenarios.find_by(id: params['scenario_id'])
        return "Scenario not found" unless scenario
        "Delete scenario '#{scenario.name}'? This will not delete the agents, only the scenario grouping."
      end

      def execute(params)
        scenario = user.scenarios.find_by(id: params['scenario_id'])
        return error_response('Scenario not found') unless scenario

        name = scenario.name
        scenario.destroy!
        success_response("Deleted scenario '#{name}'")
      end
    end

    class AddAgentToScenario < BaseTool
      def self.tool_name = 'add_agent_to_scenario'
      def self.description = 'Add existing agent to scenario'
      def self.parameters
        {
          type: 'object',
          properties: {
            scenario_id: { type: 'integer', description: 'ID of the scenario' },
            agent_id: { type: 'integer', description: 'ID of the agent to add' }
          },
          required: %w[scenario_id agent_id]
        }
      end

      def execute(params)
        scenario = user.scenarios.find_by(id: params['scenario_id'])
        return error_response('Scenario not found') unless scenario

        agent = user.agents.find_by(id: params['agent_id'])
        return error_response('Agent not found') unless agent

        if scenario.agents.include?(agent)
          error_response("Agent '#{agent.name}' is already in scenario '#{scenario.name}'")
        else
          scenario.agents << agent
          success_response("Added agent '#{agent.name}' to scenario '#{scenario.name}'")
        end
      end
    end

    class RemoveAgentFromScenario < BaseTool
      def self.tool_name = 'remove_agent_from_scenario'
      def self.description = 'Remove agent from scenario'
      def self.parameters
        {
          type: 'object',
          properties: {
            scenario_id: { type: 'integer', description: 'ID of the scenario' },
            agent_id: { type: 'integer', description: 'ID of the agent to remove' }
          },
          required: %w[scenario_id agent_id]
        }
      end

      def execute(params)
        scenario = user.scenarios.find_by(id: params['scenario_id'])
        return error_response('Scenario not found') unless scenario

        agent = scenario.agents.find_by(id: params['agent_id'])
        return error_response('Agent not found in this scenario') unless agent

        scenario.agents.delete(agent)
        success_response("Removed agent '#{agent.name}' from scenario '#{scenario.name}'")
      end
    end

    class ExportScenario < BaseTool
      def self.tool_name = 'export_scenario'
      def self.description = 'Export scenario as JSON'
      def self.parameters
        {
          type: 'object',
          properties: {
            scenario_id: { type: 'integer', description: 'ID of the scenario to export' }
          },
          required: %w[scenario_id]
        }
      end

      def execute(params)
        scenario = user.scenarios.find_by(id: params['scenario_id'])
        return error_response('Scenario not found') unless scenario

        exporter = AgentsExporter.new(
          agents: scenario.agents,
          name: scenario.name,
          description: scenario.description,
          source_url: nil,
          guid: scenario.guid
        )

        success_response("Exported scenario '#{scenario.name}'", export: exporter.as_json)
      end
    end

    class ImportScenario < BaseTool
      def self.tool_name = 'import_scenario'
      def self.description = 'Import scenario from JSON'
      def self.parameters
        {
          type: 'object',
          properties: {
            json_data: { type: 'object', description: 'Scenario JSON data' },
            merge_existing: { type: 'boolean', description: 'Merge with existing agents if true' }
          },
          required: %w[json_data]
        }
      end

      def execute(params)
        begin
          importer = AgentsImporter.new(
            file: StringIO.new(params['json_data'].to_json),
            user: user
          )
          
          if importer.import
            scenario = importer.scenario
            success_response("Imported scenario '#{scenario.name}'", scenario_id: scenario.id)
          else
            error_response("Import failed", importer.errors)
          end
        rescue => e
          error_response("Import failed: #{e.message}")
        end
      end
    end
  end
end
