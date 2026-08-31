module RemixOpenaiConcern
  extend ActiveSupport::Concern

  OPENAI_BASE_URL = 'https://api.openai.com/v1'.freeze
  DEFAULT_MODEL = 'gpt-4o'.freeze

  # Raised when the API rejects the request due to context length
  class ContextLengthExceededError < StandardError; end

  # Error patterns from various OpenAI-compatible providers
  CONTEXT_LENGTH_PATTERNS = [
    /context.?length/i,
    /token.?limit/i,
    /maximum.?context/i,
    /too.?many.?tokens/i,
    /request.*too.?large/i,
    /body.*too.?large/i,
    /max_tokens/i,
    /model.?maximum/i,
    /input.?too.?long/i,
    /reduce.?(the.?)?length/i,
    /content.?too.?long/i,
    /must be less than \d+ bytes/i
  ].freeze

  def openai_api_key
    ENV['OPENAI_API_KEY']
  end

  def openai_base_url
    (ENV['OPENAI_BASE_URL'].presence || OPENAI_BASE_URL).chomp('/')
  end

  def openai_model
    ENV['OPENAI_MODEL'].presence || DEFAULT_MODEL
  end

  # Non-streaming request: returns parsed JSON response body.
  # Raises ContextLengthExceededError if the API rejects due to context size.
  def openai_chat_completion(messages:, tools: nil)
    body = {
      model: openai_model,
      messages: messages
    }
    body[:tools] = tools if tools.present?

    response = openai_request(:post, '/chat/completions', body)
    check_context_length_error!(response)
    response
  end

  # Streaming request: yields parsed delta chunks, returns accumulated message hash
  # The block receives { type:, data: } hashes for each SSE event:
  #   { type: 'content_delta', data: "text chunk" }
  #   { type: 'tool_call_delta', data: { index:, id:, name:, arguments: } }
  #   { type: 'done', data: <full accumulated message hash> }
  def openai_chat_completion_streaming(messages:, tools: nil, &block)
    body = {
      model: openai_model,
      messages: messages,
      stream: true
    }
    body[:tools] = tools if tools.present?

    # Accumulated message that we build from deltas
    accumulated = {
      'role' => 'assistant',
      'content' => '',
      'tool_calls' => nil
    }

    openai_streaming_request('/chat/completions', body) do |chunk|
      # Defensive: skip non-Hash chunks (some providers may emit unexpected data)
      next unless chunk.is_a?(Hash) && chunk['choices'].is_a?(Array)

      choice = chunk['choices'].first
      next unless choice.is_a?(Hash)

      delta = choice['delta']
      finish_reason = choice['finish_reason']
      next unless delta || finish_reason

      if delta.is_a?(Hash)
        # Content delta
        if delta['content'].is_a?(String)
          accumulated['content'] = (accumulated['content'] || '') + delta['content']
          yield({ type: 'content_delta', data: delta['content'] }) if block_given?
        end

        # Tool call deltas
        if delta['tool_calls'].is_a?(Array)
          accumulated['tool_calls'] ||= []
          delta['tool_calls'].each do |tc_delta|
            next unless tc_delta.is_a?(Hash)
            idx = tc_delta['index']
            next unless idx.is_a?(Integer)

            accumulated['tool_calls'][idx] ||= {
              'id' => nil,
              'type' => 'function',
              'function' => { 'name' => '', 'arguments' => '' }
            }
            tc = accumulated['tool_calls'][idx]
            tc['id'] = tc_delta['id'] if tc_delta['id']

            func_delta = tc_delta['function']
            if func_delta.is_a?(Hash)
              tc['function']['name'] += func_delta['name'].to_s if func_delta['name']
              tc['function']['arguments'] += func_delta['arguments'].to_s if func_delta['arguments']
            end

            yield({
              type: 'tool_call_delta',
              data: {
                index: idx,
                id: tc['id'],
                name: tc['function']['name'],
                arguments_so_far: tc['function']['arguments']
              }
            }) if block_given?
          end
        end
      end

      if finish_reason
        # Clean up nil tool_calls
        accumulated.delete('tool_calls') if accumulated['tool_calls'].nil?
        accumulated['content'] = nil if accumulated['content'] == ''
        yield({ type: 'done', data: accumulated }) if block_given?
      end
    end

    # Clean up and return
    accumulated.delete('tool_calls') if accumulated['tool_calls'].nil?
    accumulated['content'] = nil if accumulated['content'] == ''
    accumulated
  end

  private

  def openai_request(method, path, body = nil)
    url = "#{openai_base_url}#{path}"
    conn = Faraday.new do |f|
      f.options.timeout = 120
      f.options.open_timeout = 30
      f.adapter Faraday.default_adapter
    end
    response = conn.run_request(method, url, body&.to_json, openai_headers)
    parsed = response.body
    # Ensure we always return a Hash — some providers don't set the right
    # Content-Type so Faraday may not auto-parse the JSON.
    if parsed.is_a?(String)
      begin
        parsed = JSON.parse(parsed)
      rescue JSON::ParserError
        return { 'error' => { 'message' => "Unparseable API response: #{parsed.truncate(200)}" } }
      end
    end
    parsed
  end

  def openai_streaming_request(path, body)
    url = "#{openai_base_url}#{path}"

    # Use net/http directly for reliable streaming
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.read_timeout = 120
    http.open_timeout = 30

    request = Net::HTTP::Post.new(uri.request_uri)
    openai_headers.each { |k, v| request[k] = v }
    request.body = body.to_json

    buffer = ""

    http.request(request) do |response|
      # Check HTTP-level errors (e.g. 400 with context_length_exceeded)
      unless response.is_a?(Net::HTTPSuccess)
        error_body = response.read_body rescue ''
        error_msg = safe_dig_error(error_body)
        if context_length_error?(error_msg)
          raise ContextLengthExceededError, error_msg
        end
        raise "OpenAI API error (HTTP #{response.code}): #{error_msg}"
      end

      response.read_body do |chunk|
        buffer += chunk
        while (idx = buffer.index("\n"))
          line = buffer.slice!(0, idx + 1).strip
          next if line.empty?
          next unless line.start_with?('data: ')

          data = line.delete_prefix('data: ').strip
          next if data == '[DONE]'

          begin
            json = JSON.parse(data)

            # Some providers send error objects in the stream
            if json.is_a?(Hash) && json['error']
              error_msg = safe_dig_error(json)
              if context_length_error?(error_msg)
                raise ContextLengthExceededError, error_msg
              end
            end

            yield json if block_given?
          rescue JSON::ParserError
            # Skip malformed JSON
          end
        end
      end
    end
  end

  def openai_headers
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{openai_api_key}"
    }
  end

  # Check a non-streaming response for context length errors and raise
  def check_context_length_error!(response)
    return unless response.is_a?(Hash) && response['error']
    error_msg = safe_dig_error(response)
    if context_length_error?(error_msg)
      raise ContextLengthExceededError, error_msg
    end
  end

  # Try to dig out a nice error message. If anything goes wrong, just return
  # the raw thing as a string — never crash on error handling.
  def safe_dig_error(obj)
    obj = JSON.parse(obj) if obj.is_a?(String)
    obj.dig('error', 'message') || obj.dig('error', 'code') || obj.to_s
  rescue StandardError
    obj.to_s
  end

  # Test whether an error message matches known context-length patterns
  def context_length_error?(message)
    CONTEXT_LENGTH_PATTERNS.any? { |pattern| message.to_s.match?(pattern) }
  end
end
