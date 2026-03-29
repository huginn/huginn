module Remix
  module Skills
    class WorkflowPlanningSkill < BaseSkill
      def self.name = 'workflow_planning'
      def self.description = 'Help with planning and executing complex multi-step workflows'

      def self.triggers
        ['plan', 'setup a scenario', 'build a workflow', 'complex', 'multi-step',
         'create a pipeline', 'set up', 'automate', 'end to end', 'full workflow']
      end

      def self.context(user)
        <<~CONTEXT
          ## Multi-Step Workflow Planning Guide

          ### When to Use Planning
          Use the `plan_workflow` tool when the user's request involves:
          - Creating 3 or more agents that connect together
          - Setting up a complete scenario from scratch
          - Building a pipeline (source → processor → output)
          - Complex changes that touch multiple agents

          ### Planning Process
          1. **Analyze**: Understand what the user wants to achieve
          2. **Plan**: Use `plan_workflow` to create a step-by-step plan
          3. **Present**: Show the plan to the user and explain each step
          4. **Execute**: Execute each step in order using the appropriate tools
          5. **Review**: Use `review_plan` to summarize what was done and check for issues

          ### Common Workflow Patterns

          **RSS/Website Monitoring → Filter → Notify**
          1. Create WebsiteAgent or RssAgent (source)
          2. Create TriggerAgent (filter)
          3. Create notification agent (Slack, Email, etc.)
          4. Connect: Source → Filter → Notification
          5. Create scenario to group them
          6. Add all agents to scenario

          **Webhook → Process → Forward**
          1. Create WebhookAgent (input)
          2. Create JavaScriptAgent (transformation)
          3. Create PostAgent (output)
          4. Connect the chain
          5. Create and populate scenario

          **Multi-Source Aggregation**
          1. Create multiple source agents
          2. Create DataOutputAgent or aggregation agent
          3. Connect all sources to the aggregator
          4. Optionally add notification

          ### Best Practices
          - Always create the scenario first, then add agents to it
          - Create agents in dependency order (sources first, then processors, then outputs)
          - Set agents as disabled initially if testing is needed
          - Use `dry_run_agent` to test each agent after creation
          - After executing all steps, use `review_plan` to verify everything worked
          - If a step fails, explain the error and attempt to fix it before continuing
        CONTEXT
      end
    end
  end
end
