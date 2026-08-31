module Remix
  class Orchestrator
    include RemixOpenaiConcern

    MAX_TOOL_ITERATIONS = 20
    MAX_COMPACTION_RETRIES = 15  # 15 * 5% = 75% max removal

    def initialize(remix_conversation)
      @remix = remix_conversation
      @user = remix_conversation.user
      @compacted_count = 0  # track how many messages have been dropped
    end

    # Non-streaming: keeps existing behaviour for fallback / JSON endpoint
    def process_message(content)
      @remix.messages.create!(role: 'user', content: content)

      iteration = 0
      assistant_message = nil

      while iteration < MAX_TOOL_ITERATIONS
        response = chat_completion_with_compaction
        assistant_message = save_assistant_message(response)

        tool_calls = response.dig('choices', 0, 'message', 'tool_calls')

        if tool_calls.present?
          tool_results = execute_tools(tool_calls)
          break if tool_results.any? { |r| r[:pending_confirmation] }
          iteration += 1
        else
          break
        end
      end

      # Auto-generate title on first exchange
      begin
        TitleGenerator.new(@remix).generate
      rescue => e
        Rails.logger.warn("Title generation failed: #{e.message}")
      end

      assistant_message
    end

    # Streaming: yields SSE-formatted event strings.
    # Each yielded string is a complete "data: ...\n\n" SSE event.
    def process_message_streaming(content)
      @remix.messages.create!(role: 'user', content: content)

      iteration = 0

      while iteration < MAX_TOOL_ITERATIONS
        # Stream the LLM response (with compaction on context-length errors)
        accumulated = nil
        full_content = ''

        accumulated = chat_completion_streaming_with_compaction do |event|
          case event[:type]
          when 'content_delta'
            full_content += event[:data]
            yield sse_event('content_delta', { text: event[:data] })

          when 'tool_call_delta'
            d = event[:data]
            yield sse_event('tool_call_delta', {
              index: d[:index], id: d[:id],
              name: d[:name]
            })

          when 'compaction'
            yield sse_event('compaction', {
              dropped: event[:dropped],
              remaining: event[:remaining],
              attempt: event[:attempt]
            })

          when 'done'
            # nothing yet — we persist below
          end
        end

        # Defensive: ensure accumulated is a Hash
        accumulated = { 'content' => accumulated.to_s } unless accumulated.is_a?(Hash)

        # Persist the assistant message
        assistant_msg = @remix.messages.create!(
          role: 'assistant',
          content: accumulated['content'],
          tool_calls: accumulated['tool_calls']
        )

        yield sse_event('assistant_saved', { message_id: assistant_msg.id })

        # Check for tool calls
        if accumulated['tool_calls'].present?
          yield sse_event('tool_execution_start', { count: accumulated['tool_calls'].size })

          tool_results = execute_tools_streaming(accumulated['tool_calls']) do |tool_event|
            yield tool_event
          end

          pending = tool_results.select { |r| r[:pending_confirmation] }
          if pending.any?
            pending.each do |p|
              yield sse_event('confirmation_required', {
                tool_call_id: p[:tool_call_id],
                tool_name: p[:tool_name],
                message: p[:message]
              })
            end
            break
          end

          iteration += 1
          yield sse_event('next_iteration', { iteration: iteration })
        else
          break
        end
      end

      # Auto-generate a title if this is the first exchange
      begin
        new_title = TitleGenerator.new(@remix).generate
        if new_title
          yield sse_event('title_updated', { title: new_title })
        end
      rescue => e
        Rails.logger.warn("Title generation failed: #{e.message}")
      end

      yield sse_event('stream_end', {})
    end

    def continue_after_confirmation
      iteration = 0
      while iteration < MAX_TOOL_ITERATIONS
        response = chat_completion_with_compaction
        assistant_message = save_assistant_message(response)

        tool_calls = response.dig('choices', 0, 'message', 'tool_calls')

        if tool_calls.present?
          tool_results = execute_tools(tool_calls)
          break if tool_results.any? { |r| r[:pending_confirmation] }
          iteration += 1
        else
          break
        end
      end

      assistant_message
    end

    private

    # ---- Context compaction ----

    # Build the full message array for the API.
    # @param drop_count [Integer] number of conversation messages to drop from
    #   the beginning (after the system message).
    def build_messages(drop_count: 0)
      system_message = { role: 'system', content: system_context }
      conversation = @remix.conversation_for_api

      if drop_count > 0 && conversation.size > drop_count
        conversation = compact_messages(conversation, drop_count)
      end

      [system_message] + conversation
    end

    # Remove `count` messages from the front of the conversation, respecting
    # tool_call / tool_response pairing. We never orphan a tool response
    # (role: tool) from its preceding assistant message with tool_calls, and
    # we never leave an assistant message with tool_calls if the tool
    # responses that follow it have been kept but the assistant itself is
    # dropped.
    def compact_messages(conversation, count)
      return conversation if count <= 0 || conversation.empty?

      # Find a safe cut point: we walk forward `count` messages and then
      # extend the cut to avoid breaking tool_call/tool pairs.
      cut = [count, conversation.size - 1].min  # always keep at least the last message

      # Extend forward past any orphaned tool responses at the cut boundary
      while cut < conversation.size && conversation[cut][:role] == 'tool'
        cut += 1
      end

      # If we'd drop everything, keep at least the last message
      cut = conversation.size - 1 if cut >= conversation.size

      dropped = conversation[0...cut]
      remaining = conversation[cut..]

      # Safety: if the remaining conversation starts with a tool message
      # (shouldn't happen after the loop above, but be safe), prepend a
      # synthetic note so the API doesn't reject orphaned tool messages
      if remaining.first && remaining.first[:role] == 'tool'
        remaining = [{ role: 'user', content: '[Earlier conversation messages were compacted to fit context limits.]' }] + remaining
      end

      Rails.logger.info("Remix compaction: dropped #{dropped.size} messages, #{remaining.size} remaining")
      remaining
    end

    # Non-streaming API call with automatic compaction retry
    def chat_completion_with_compaction
      retries = 0

      begin
        messages = build_messages(drop_count: @compacted_count)
        openai_chat_completion(messages: messages, tools: ToolRegistry.all_tools)
      rescue RemixOpenaiConcern::ContextLengthExceededError => e
        retries += 1
        if retries > MAX_COMPACTION_RETRIES
          raise "Context still too long after #{retries} compaction attempts (dropped #{@compacted_count} messages): #{e.message}"
        end

        total_conversation = @remix.conversation_for_api.size
        drop_increment = [(total_conversation * 0.05).ceil, 1].max
        @compacted_count += drop_increment

        Rails.logger.warn(
          "Remix context too long (attempt #{retries}): dropping #{@compacted_count}/#{total_conversation} messages from context"
        )
        retry
      end
    end

    # Streaming API call with automatic compaction retry.
    # Yields SSE events including 'compaction' events when retrying.
    def chat_completion_streaming_with_compaction(&block)
      retries = 0

      begin
        messages = build_messages(drop_count: @compacted_count)
        openai_chat_completion_streaming(messages: messages, tools: ToolRegistry.all_tools, &block)
      rescue RemixOpenaiConcern::ContextLengthExceededError => e
        retries += 1
        if retries > MAX_COMPACTION_RETRIES
          raise "Context still too long after #{retries} compaction attempts (dropped #{@compacted_count} messages): #{e.message}"
        end

        total_conversation = @remix.conversation_for_api.size
        drop_increment = [(total_conversation * 0.05).ceil, 1].max
        @compacted_count += drop_increment

        Rails.logger.warn(
          "Remix context too long (attempt #{retries}): dropping #{@compacted_count}/#{total_conversation} messages from context"
        )

        # Notify the frontend about compaction
        yield({ type: 'compaction', dropped: @compacted_count, remaining: total_conversation - @compacted_count, attempt: retries }) if block_given?

        retry
      end
    end

    # ---- System context ----

    def system_context
      base_context = @remix.system_context_cache.presence ||
                     ContextBuilder.new(@user).build.tap do |ctx|
                       @remix.update!(system_context_cache: ctx)
                     end

      # Inject relevant skill context based on the latest user message
      skill_context = active_skills_context
      if skill_context.present?
        base_context + "\n\n" + skill_context
      else
        base_context
      end
    end

    def active_skills_context
      latest_user_message = @remix.messages.where(role: 'user').order(created_at: :desc).first
      return "" unless latest_user_message

      matched = all_skill_classes.select { |s| s.matches?(latest_user_message.content.to_s) }
      return "" if matched.empty?

      matched.map { |s| s.context(@user) }.join("\n\n")
    end

    def all_skill_classes
      [
        Skills::AgentManagementSkill,
        Skills::ScenarioManagementSkill,
        Skills::EventAnalysisSkill,
        Skills::DiagramAnalysisSkill,
        Skills::WorkflowPlanningSkill,
        Skills::CodeExecutionSkill,
        Skills::DocumentationSkill
      ]
    end

    # ---- Message persistence ----

    def save_assistant_message(response)
      # Defensive: ensure response is a Hash
      response = JSON.parse(response) if response.is_a?(String)

      if response['error']
        error_msg = response.dig('error', 'message') || response['error'].to_s
        raise "OpenAI API error: #{error_msg}"
      end

      choice = response.dig('choices', 0, 'message')
      unless choice
        Rails.logger.error("Unexpected API response: #{response.inspect}")
        raise "Unexpected API response format"
      end

      @remix.messages.create!(
        role: 'assistant',
        content: choice['content'],
        tool_calls: choice['tool_calls']
      )
    end

    # ---- Tool execution (synchronous, with background job logging) ----

    def execute_tools(tool_calls)
      tool_calls.map do |tc|
        result = execute_single_tool(tc)
        @remix.messages.create!(
          role: 'tool',
          tool_call_id: tc['id'],
          tool_name: tc['function']['name'],
          content: result.to_json
        )
        result
      end
    end

    def execute_tools_streaming(tool_calls)
      tool_calls.map do |tc|
        tool_name = tc['function']['name']
        yield sse_event('tool_start', { id: tc['id'], name: tool_name })

        result = execute_single_tool(tc)

        msg = @remix.messages.create!(
          role: 'tool',
          tool_call_id: tc['id'],
          tool_name: tool_name,
          content: result.to_json
        )

        yield sse_event('tool_result', {
          id: tc['id'],
          name: tool_name,
          message_id: msg.id,
          result: result
        })

        result
      end
    end

    def execute_single_tool(tc)
      # Defensive: ensure tc has expected structure
      func = tc['function']
      func = JSON.parse(func) if func.is_a?(String)

      tool_name = func['name'].to_s
      tool_class = ToolRegistry.find_tool(tool_name)

      unless tool_class
        result = { error: "Unknown tool: #{tool_name}" }
        log_tool_result(tool_name, {}, result, error: true)
        return result
      end

      tool = tool_class.new(@user)

      begin
        raw_args = func['arguments']
        params = raw_args.is_a?(String) ? JSON.parse(raw_args) : (raw_args || {})
      rescue JSON::ParserError => e
        truncated = raw_args.to_s.truncate(500)
        result = {
          error: "Invalid JSON in arguments for #{tool_name}. Parse error: #{e.message}. " \
                 "Please fix the JSON and call the tool again. Your input was: #{truncated}"
        }
        log_tool_result(tool_name, {}, result, error: true)
        return result
      end

      if tool.requires_confirmation?
        {
          pending_confirmation: true,
          tool_call_id: tc['id'],
          tool_name: tool_name,
          message: tool.confirmation_message(params),
          params: params
        }
      else
        begin
          result = tool.execute(params)
          log_tool_result(tool_name, params, result)
          result
        rescue => e
          result = { error: "Tool execution failed: #{e.message}" }
          log_tool_result(tool_name, params, result, error: true)
          result
        end
      end
    end

    # Log tool execution inline — Rails logger + AgentLog.
    def log_tool_result(tool_name, params, result, error: false)
      level  = error ? 4 : 3
      status = error ? 'FAILED' : 'OK'
      msg    = "[Remix Tool] #{tool_name} #{status}"
      msg   += ": #{result[:error] || result['error']}" if error

      error ? Rails.logger.error(msg) : Rails.logger.info(msg)

      if (agent = @user.agents.first)
        AgentLog.log_for_agent(agent, msg, level: level)
      end
    rescue => e
      Rails.logger.warn("Failed to log tool result for #{tool_name}: #{e.message}")
    end

    def sse_event(type, data)
      "data: #{({ type: type }.merge(data)).to_json}\n\n"
    end
  end
end
