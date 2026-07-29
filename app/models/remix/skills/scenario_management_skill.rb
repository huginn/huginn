module Remix
  module Skills
    class ScenarioManagementSkill < BaseSkill
      def self.name = 'scenario_management'
      def self.description = 'Help with organizing agents into scenarios'

      def self.triggers
        ['create scenario', 'new scenario', 'organize agents', 'scenario',
         'group agents', 'workflow']
      end

      def self.context(user)
        <<~CONTEXT
          ## Scenario Management Guide

          ### What are Scenarios?
          Scenarios are collections of related agents that work together to accomplish a goal.
          They help you organize and visualize your automation workflows.

          ### Creating Scenarios
          When creating a scenario:
          1. Give it a descriptive name (e.g., "Weather Monitoring", "Social Media Alerts")
          2. Add a clear description of what the scenario does
          3. Choose an appropriate icon for easy identification

          ### Common Scenario Patterns

          **Monitoring & Alerting**
          - WebsiteAgent → TriggerAgent → SlackAgent/EmailAgent
          - Purpose: Monitor a website for changes and send alerts

          **Data Collection & Processing**
          - RssAgent → JavaScriptAgent → DataOutputAgent
          - Purpose: Collect RSS feeds, process/filter, and store

          **API Integration**
          - WebhookAgent → JavaScriptAgent → PostAgent
          - Purpose: Receive webhooks, transform data, send to another API

          **Social Media Automation**
          - TwitterAgent → TriggerAgent → MultipleAgents
          - Purpose: Monitor social media and trigger various responses

          ### Best Practices
          - Keep scenarios focused on a single workflow or goal
          - Use clear naming conventions
          - Document complex scenarios in the description field
          - Export scenarios as JSON for backup and sharing
        CONTEXT
      end
    end
  end
end
