module Remix
  class ToolRegistry
    TOOLS = [
      # Agent tools
      Tools::ListAgents,
      Tools::GetAgent,
      Tools::CreateAgent,
      Tools::UpdateAgent,
      Tools::DeleteAgent,
      Tools::DryRunAgent,
      Tools::GetAgentMemory,
      Tools::UpdateAgentMemory,

      # Scenario tools
      Tools::ListScenarios,
      Tools::GetScenario,
      Tools::CreateScenario,
      Tools::UpdateScenario,
      Tools::DeleteScenario,
      Tools::AddAgentToScenario,
      Tools::RemoveAgentFromScenario,
      Tools::ExportScenario,
      Tools::ImportScenario,

      # Link tools
      Tools::ConnectAgents,
      Tools::DisconnectAgents,
      Tools::AddControlLink,
      Tools::RemoveControlLink,

      # Event tools
      Tools::SearchEvents,
      Tools::GetEvent,
      Tools::AnalyzeEventFlow,
      Tools::GetRecentErrors,
      Tools::ReEmitEvent,

      # Diagram tools
      Tools::GetFlowDiagram,
      Tools::AnalyzeFlow,

      # Web fetch
      Tools::WebFetchTool,

      # Planning tools
      Tools::PlanWorkflow,
      Tools::ReviewPlan,

      # Code execution
      Tools::EvaluateCodeTool,

      # Documentation docsets
      Tools::ListDocsets,
      Tools::InstallDocset,
      Tools::SearchDocs,
      Tools::UninstallDocset,

      # OpenAPI specs
      Tools::ListApiSpecs,
      Tools::InstallApiSpec,
      Tools::UninstallApiSpec
    ].freeze

    def self.all_tools
      TOOLS.map(&:to_openai_tool)
    end

    def self.find_tool(name)
      TOOLS.find { |t| t.tool_name == name }
    end
  end
end
