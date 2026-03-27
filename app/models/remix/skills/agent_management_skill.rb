module Remix
  module Skills
    class AgentManagementSkill < BaseSkill
      def self.name = 'agent_management'
      def self.description = 'Detailed guidance for creating and configuring agents'

      def self.triggers
        ['create agent', 'new agent', 'add agent', 'configure agent',
         'agent options', 'agent settings', 'setup agent', 'make agent']
      end

      def self.context(user)
        <<~CONTEXT
          ## Agent Management - Detailed Guide

          ### Creating Agents
          When creating an agent, you need:
          1. **type**: Full class name like "Agents::WebsiteAgent"
          2. **name**: Human-readable identifier
          3. **options**: Type-specific configuration (JSON object)
          4. **schedule** (optional): When to run ("every_1h", "every_5m", "midnight", etc.)

          ### Common Agent Type Configurations

          #### WebsiteAgent
          Scrapes websites and extracts data.
          ```json
          {
            "url": "https://example.com",
            "type": "html",
            "mode": "on_change",
            "extract": {
              "title": { "css": "h1", "value": "string(.)" },
              "price": { "css": ".price", "value": "string(.)" }
            }
          }
          ```

          #### TriggerAgent
          Filters events based on conditions.
          ```json
          {
            "rules": [
              { "type": "field>=value", "path": "price", "value": "100" }
            ],
            "message": "Price alert: {{price}}"
          }
          ```

          #### PostAgent
          Makes HTTP POST requests.
          ```json
          {
            "url": "https://api.example.com/notify",
            "method": "post",
            "payload": { "text": "{{message}}" },
            "headers": { "Authorization": "Bearer {{credential api_key}}" }
          }
          ```

          #### SlackAgent
          Sends messages to Slack.
          ```json
          {
            "webhook_url": "{% credential slack_webhook %}",
            "channel": "#alerts",
            "username": "Huginn",
            "message": "{{message}}"
          }
          ```

          ### Liquid Templates
          Use `{{variable}}` syntax in options:
          - `{{event.payload.field}}` - Access incoming event data
          - `{% credential name %}` - Use stored credentials
          - `{{agent.memory.key}}` - Access agent memory
          - Filters: `{{text | upcase}}`, `{{url | uri_escape}}`

          ### Best Practices
          - Always test new agents with dry_run first
          - Use meaningful names that describe what the agent does
          - Set appropriate schedules (don't poll too frequently)
          - Connect agents in logical workflows
        CONTEXT
      end
    end
  end
end
