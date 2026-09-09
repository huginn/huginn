module Remix
  module Tools
    class PlanWorkflow < BaseTool
      def self.tool_name = 'plan_workflow'
      def self.description = 'Create or update a multi-step workflow plan. Use this to break complex user requests into discrete steps before executing them. Each step should be a single tool call. Returns the plan for user review before execution.'
      def self.parameters
        {
          type: 'object',
          properties: {
            goal: { type: 'string', description: 'High-level description of what the workflow should accomplish' },
            steps: {
              type: 'array',
              description: 'Ordered list of steps to execute',
              items: {
                type: 'object',
                properties: {
                  step_number: { type: 'integer', description: 'Step number (1-based)' },
                  description: { type: 'string', description: 'What this step does' },
                  tool: { type: 'string', description: 'Which tool to call for this step' },
                  depends_on: {
                    type: 'array',
                    items: { type: 'integer' },
                    description: 'Step numbers that must complete before this step'
                  }
                },
                required: %w[step_number description tool]
              }
            }
          },
          required: %w[goal steps]
        }
      end

      def execute(params)
        goal = params['goal']
        steps = params['steps'] || []

        # Store the plan in the conversation's remix memory via a simple model attribute
        plan = {
          goal: goal,
          steps: steps.map { |s|
            {
              step_number: s['step_number'],
              description: s['description'],
              tool: s['tool'],
              depends_on: s['depends_on'] || [],
              status: 'pending'
            }
          },
          created_at: Time.current.iso8601
        }

        plan_summary = steps.map { |s|
          deps = s['depends_on']&.any? ? " (after step #{s['depends_on'].join(', ')})" : ""
          "  #{s['step_number']}. #{s['description']} [#{s['tool']}]#{deps}"
        }.join("\n")

        success_response(
          "Workflow plan created with #{steps.size} steps",
          {
            plan: plan,
            summary: "**Goal:** #{goal}\n\n**Steps:**\n#{plan_summary}"
          }
        )
      end
    end

    class ReviewPlan < BaseTool
      def self.tool_name = 'review_plan'
      def self.description = 'After executing all steps of a plan, use this to review the results, check for issues, and suggest next steps or improvements.'
      def self.parameters
        {
          type: 'object',
          properties: {
            goal: { type: 'string', description: 'The original goal of the plan' },
            completed_steps: {
              type: 'array',
              description: 'List of completed step summaries',
              items: {
                type: 'object',
                properties: {
                  step_number: { type: 'integer' },
                  description: { type: 'string' },
                  result: { type: 'string', description: 'Summary of what happened' },
                  success: { type: 'boolean' }
                },
                required: %w[step_number description result success]
              }
            },
            issues: {
              type: 'array',
              items: { type: 'string' },
              description: 'Any issues encountered during execution'
            }
          },
          required: %w[goal completed_steps]
        }
      end

      def execute(params)
        goal = params['goal']
        steps = params['completed_steps'] || []
        issues = params['issues'] || []

        total = steps.size
        succeeded = steps.count { |s| s['success'] }
        failed = total - succeeded

        review = steps.map { |s|
          icon = s['success'] ? '✓' : '✗'
          "  #{icon} Step #{s['step_number']}: #{s['description']} — #{s['result']}"
        }.join("\n")

        issue_text = issues.any? ? "\n\n**Issues:**\n" + issues.map { |i| "  - #{i}" }.join("\n") : ""

        success_response(
          "Plan review complete: #{succeeded}/#{total} steps succeeded",
          {
            goal: goal,
            total_steps: total,
            succeeded: succeeded,
            failed: failed,
            review: "**Goal:** #{goal}\n\n**Results:**\n#{review}#{issue_text}",
            all_succeeded: failed == 0
          }
        )
      end
    end
  end
end
