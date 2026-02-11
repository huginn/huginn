module Agents
  class OpenaiLlmAgent < Agent
    include OpenaiConcern

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description <<~MD
      The OpenAI LLM Agent sends chat completion requests to any OpenAI-compatible API and emits the response as an event.

      It works with OpenAI, Azure OpenAI, Ollama, Groq, vLLM, LiteLLM, and any other service exposing an OpenAI-compatible `/v1/chat/completions` endpoint.

      ### Configuration

      * `api_key` - Your API key (use `{% credential openai_api_key %}`). Falls back to the `OPENAI_API_KEY` environment variable.
      * `base_url` - The API base URL. Defaults to `https://api.openai.com/v1`. Falls back to the `OPENAI_BASE_URL` environment variable. Set to `http://localhost:11434/v1` for Ollama, etc.
      * `organization` - (Optional) OpenAI organization ID.
      * `model` - The model to use (e.g. `gpt-4o`, `gpt-4o-mini`, `llama3`).
      * `system_message` - (Optional) A system prompt to set the assistant's behavior.
      * `user_message` - The user message to send. Supports [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) templating.
      * `temperature` - (Optional) Sampling temperature between 0 and 2. Default: 1.
      * `max_tokens` - (Optional) Maximum number of tokens to generate.
      * `top_p` - (Optional) Nucleus sampling parameter.
      * `frequency_penalty` - (Optional) Penalize repeated tokens. Between -2.0 and 2.0.
      * `presence_penalty` - (Optional) Penalize tokens based on presence. Between -2.0 and 2.0.
      * `response_format` - (Optional) Set to `json_object` to force JSON output.
      * `request_timeout` - (Optional) Timeout in seconds for API requests. Default: 60. Max: 600.
      * `output_mode` - (Optional) Set to `merge` to merge the original event payload into the emitted event. Default: `clean`.
      * `expected_receive_period_in_days` - How often you expect events to arrive.

      ### Event Handling

      When receiving events, the `user_message` field is interpolated with the incoming event's payload, allowing you to use Liquid tags like `{{ message }}` or `{{ content }}`.

      When `output_mode` is set to `merge`, the emitted event will contain the original incoming event's payload with the LLM response fields merged on top.
    MD

    event_description <<~MD
      Events look like this:

          {
            "message": "The assistant's response text",
            "finish_reason": "stop",
            "model": "gpt-4o",
            "usage": {
              "prompt_tokens": 50,
              "completion_tokens": 100,
              "total_tokens": 150
            },
            "full_response": { ... }
          }

      Original event contents will be merged when `output_mode` is set to `merge`.
    MD

    def default_options
      {
        'api_key' => '{% credential openai_api_key %}',
        'base_url' => '',
        'organization' => '',
        'model' => 'gpt-4o-mini',
        'system_message' => 'You are a helpful assistant.',
        'user_message' => '{{ message }}',
        'temperature' => '1',
        'max_tokens' => '',
        'top_p' => '',
        'frequency_penalty' => '',
        'presence_penalty' => '',
        'response_format' => 'text',
        'output_mode' => 'clean',
        'request_timeout' => '60',
        'expected_receive_period_in_days' => '1'
      }
    end

    def validate_options
      validate_openai_options!

      errors.add(:base, "model is required") unless options['model'].present?
      errors.add(:base, "user_message is required") unless options['user_message'].present?

      if options['temperature'].present?
        temp = options['temperature'].to_f
        errors.add(:base, "temperature must be between 0 and 2") unless temp >= 0 && temp <= 2
      end

      if options['max_tokens'].present? && options['max_tokens'].to_i <= 0
        errors.add(:base, "max_tokens must be a positive integer")
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          perform_completion(event)
        end
      end
    end

    def check
      perform_completion
    end

    private

    def perform_completion(event = nil)
      body = build_request_body
      response = openai_request(:post, '/chat/completions', body)

      return if handle_openai_error(response)

      choice = response.dig('choices', 0)
      return error("No choices returned from API") unless choice

      create_event payload: openai_base_payload(event).merge(
        'message' => choice.dig('message', 'content'),
        'finish_reason' => choice['finish_reason'],
        'model' => response['model'],
        'usage' => response['usage'],
        'full_response' => response
      )
    end

    def build_request_body
      messages = []

      if interpolated['system_message'].present?
        messages << { 'role' => 'system', 'content' => interpolated['system_message'] }
      end

      messages << { 'role' => 'user', 'content' => interpolated['user_message'] }

      body = {
        'model' => interpolated['model'],
        'messages' => messages
      }

      body['temperature'] = interpolated['temperature'].to_f if interpolated['temperature'].present?
      body['max_tokens'] = interpolated['max_tokens'].to_i if interpolated['max_tokens'].present?
      body['top_p'] = interpolated['top_p'].to_f if interpolated['top_p'].present?
      body['frequency_penalty'] = interpolated['frequency_penalty'].to_f if interpolated['frequency_penalty'].present?
      body['presence_penalty'] = interpolated['presence_penalty'].to_f if interpolated['presence_penalty'].present?

      if interpolated['response_format'] == 'json_object'
        body['response_format'] = { 'type' => 'json_object' }
      end

      body
    end
  end
end
