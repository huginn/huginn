# Remix - AI Assistant for Huginn

## Overview

**Remix** is an AI-powered conversational interface for Huginn that helps you create, manage, and debug your automation workflows. Think of it as having an expert Huginn assistant available 24/7.

## Features

Remix can help you with:

- **Agent Management**: Create, configure, update, and delete agents
- **Scenario Organization**: Set up and manage scenarios
- **Event Analysis**: Search, analyze, and debug events
- **Flow Diagram Analysis**: Visualize and optimize your workflows
- **Template Management**: Create reusable agent templates
- **Troubleshooting**: Debug issues and fix broken agents

## Setup

### 1. Environment Configuration

Add the following to your `.env` file:

```bash
# Required: Your OpenAI API key
OPENAI_API_KEY=sk-your-api-key-here

# Optional: Custom base URL (for Azure OpenAI, OpenRouter, etc.)
OPENAI_BASE_URL=https://api.openai.com/v1

# Optional: Model selection (defaults to gpt-4o)
OPENAI_MODEL=gpt-4o
```

### 2. Run Migrations

```bash
bundle exec rake db:migrate
```

### 3. Restart Your Server

```bash
# Development
bundle exec rails server

# Production
# Restart your application server
```

## Usage

### Accessing Remix

1. Navigate to the **Remix** menu item in the top navigation (look for the sparkle icon ✨)
2. Click "New Conversation" to start chatting with Remix

### Example Conversations

#### Creating Agents

```
You: Create a website monitoring agent for example.com that checks every hour

Remix: I'll create a WebsiteAgent for you...
[Creates agent with appropriate configuration]
```

#### Debugging Issues

```
You: Why isn't my weather agent working?

Remix: Let me check...
[Analyzes recent errors, checks event flow, provides diagnosis]
```

#### Analyzing Workflows

```
You: Show me my flow diagram and find any issues

Remix: Here's your current flow...
[Displays diagram description and identifies potential problems]
```

## Available Tools

Remix has access to 35+ tools organized into categories:

### Agent Tools
- `list_agents` - List all agents with filtering
- `get_agent` - Get detailed agent configuration
- `create_agent` - Create new agents
- `update_agent` - Modify existing agents
- `delete_agent` - Remove agents (with confirmation)
- `dry_run_agent` - Test agents without persisting
- `get_agent_memory` / `update_agent_memory` - Manage agent memory

### Scenario Tools
- `list_scenarios` - List all scenarios
- `get_scenario` - Get scenario details
- `create_scenario` - Create new scenarios
- `update_scenario` - Modify scenarios
- `add_agent_to_scenario` / `remove_agent_from_scenario` - Manage scenario membership
- `export_scenario` / `import_scenario` - Backup and restore scenarios

### Link Tools
- `connect_agents` - Create event flow links
- `disconnect_agents` - Remove event flow links
- `add_control_link` / `remove_control_link` - Manage control relationships

### Event Tools
- `search_events` - Search events with filters
- `get_event` - Get event details
- `analyze_event_flow` - Trace event propagation
- `get_recent_errors` - Retrieve error logs
- `re_emit_event` - Reprocess events

### Diagram Tools
- `get_flow_diagram` - Get current flow visualization
- `analyze_flow` - Identify potential issues

### Template Tools
- `list_templates` - Show available templates
- `create_from_template` - Instantiate templates
- `save_as_template` - Save agents as templates

## Skills System

Remix loads contextual skills based on your questions:

- **Agent Management Skill**: Detailed agent creation guidance
- **Scenario Management Skill**: Workflow organization patterns
- **Event Analysis Skill**: Debugging and troubleshooting
- **Diagram Analysis Skill**: Flow optimization
- **Template Management Skill**: Template usage patterns

## Confirmation System

Destructive operations (like deleting agents) require explicit confirmation in the UI. Remix will:

1. Explain what will be deleted
2. Show a confirmation button
3. Wait for your approval before proceeding

## Architecture

```
┌─────────────────────────────────────┐
│         Remix UI (Chat)             │
└─────────────────────────────────────┘
                  │
┌─────────────────────────────────────┐
│      RemixesController              │
└─────────────────────────────────────┘
                  │
┌─────────────────────────────────────┐
│      Remix::Orchestrator            │
│  - Manages conversation flow        │
│  - Calls OpenAI API                 │
│  - Executes tools                   │
└─────────────────────────────────────┘
         │                │
┌────────────────┐  ┌────────────────┐
│  ContextBuilder│  │  ToolRegistry  │
│  - System info │  │  - 35+ tools   │
│  - Agent list  │  │  - Categories  │
│  - Flow state  │  │  - Execution   │
└────────────────┘  └────────────────┘
```

## Database Schema

### `remixes` table
- `id` - Primary key
- `user_id` - Owner of the conversation
- `title` - Conversation title
- `system_context_cache` - Cached system context
- `created_at`, `updated_at` - Timestamps

### `remix_messages` table
- `id` - Primary key
- `remix_id` - Conversation reference
- `role` - Message role (user, assistant, system, tool)
- `content` - Message content
- `tool_calls` - JSON array of tool calls (for assistant messages)
- `tool_call_id` - Tool call identifier (for tool result messages)
- `tool_name` - Name of the executed tool
- `created_at`, `updated_at` - Timestamps

## Cost Considerations

### Token Usage

Remix conversations can consume significant tokens because:

1. **System Context**: Each conversation starts with a comprehensive system prompt containing:
   - List of all agent types and descriptions
   - Your current agents and their status
   - Your scenarios
   - Flow diagram (DOT format)
   - Recent errors

2. **Conversation History**: The full conversation is sent with each message

3. **Tool Definitions**: All 35+ tools are sent with each request

### Cost Estimation

Typical usage (with gpt-4o at $2.50/1M input tokens, $10/1M output tokens):

- **Initial system context**: ~5,000-10,000 tokens
- **Per message**: ~500-2,000 tokens
- **Tool execution**: ~100-500 tokens per tool

Example conversation cost (10 messages, 3 tool calls): ~$0.10-0.50

### Cost Optimization Tips

1. **Clear Conversations**: Delete old conversations you don't need
2. **Be Specific**: Ask focused questions to reduce back-and-forth
3. **Use Appropriate Models**: Consider gpt-3.5-turbo for simple tasks
4. **Batch Operations**: Ask for multiple changes in one message

## Security Considerations

### Access Control

- Remix is authenticated via Devise (same as Huginn)
- Each user can only access their own conversations
- Tools are scoped to `current_user` - no cross-user access

### API Key Security

- Store `OPENAI_API_KEY` in environment variables, never in code
- Use read-only filesystem access in production
- Consider rate limiting if running a multi-user instance

### Destructive Operations

- Deletions require explicit user confirmation
- Tool execution logs are preserved in conversation history
- Failed operations return error messages instead of crashing

## Troubleshooting

### "Error: No OpenAI API key configured"

**Solution**: Set `OPENAI_API_KEY` in your `.env` file

### "Error: Failed to connect to OpenAI API"

**Solutions**:
- Check your internet connection
- Verify API key is valid
- Check `OPENAI_BASE_URL` if using a custom endpoint
- Review firewall/proxy settings

### Remix is slow to respond

**Causes**:
- Large system context (many agents/scenarios)
- Complex tool executions
- OpenAI API latency

**Solutions**:
- Use a faster model (gpt-3.5-turbo)
- Reduce number of agents in your system
- Clear old events to reduce context size

### Tools are not executing

**Check**:
- Look for error messages in tool result blocks
- Check agent/scenario permissions
- Verify database connectivity
- Review Rails logs for detailed errors

## Development

### Adding New Tools

1. Create tool class in `app/models/remix/tools/`:

```ruby
module Remix
  module Tools
    class MyNewTool < BaseTool
      def self.tool_name = 'my_new_tool'
      def self.description = 'Description for AI'
      def self.parameters
        {
          type: 'object',
          properties: {
            param1: { type: 'string', description: 'Parameter 1' }
          },
          required: %w[param1]
        }
      end

      def execute(params)
        # Your implementation
        success_response("Success message", data: {})
      end
    end
  end
end
```

2. Register in `app/models/remix/tool_registry.rb`:

```ruby
TOOLS = [
  # ... existing tools
  Tools::MyNewTool,
].freeze
```

### Adding New Skills

Create skill class in `app/models/remix/skills/`:

```ruby
module Remix
  module Skills
    class MyNewSkill < BaseSkill
      def self.name = 'my_skill'
      def self.description = 'When to load this skill'
      
      def self.triggers
        ['keyword1', 'keyword2']
      end
      
      def self.context(user)
        <<~CONTEXT
          # Additional context to provide when skill is active
        CONTEXT
      end
    end
  end
end
```

## Testing

```bash
# Run all tests
./run_tests.sh

# Run specific Remix tests
./run_tests.sh spec/models/remix_spec.rb

# Test specific tool
./run_tests.sh spec/models/remix/tools/agent_tools_spec.rb
```

## Future Enhancements

Potential improvements:

- [ ] Streaming responses (Server-Sent Events)
- [ ] Voice input/output
- [ ] Multi-turn planning for complex workflows
- [ ] Agent suggestions based on common patterns
- [ ] Integration with external documentation
- [ ] Export conversations as documentation
- [ ] Collaborative features (share conversations)
- [ ] Custom tool plugins
- [ ] Rate limiting per user
- [ ] Usage analytics dashboard

## License

Remix is part of Huginn and follows the same license (MIT).

## Support

For issues, questions, or contributions:

1. Check the [Huginn documentation](https://github.com/huginn/huginn)
2. Search existing GitHub issues
3. Open a new issue with details about your problem

## Credits

- Built for Huginn by the community
- Powered by OpenAI's GPT models
- Inspired by Claude Code, OpenCode, and similar AI assistants
