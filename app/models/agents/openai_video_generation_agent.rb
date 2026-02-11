module Agents
  class OpenaiVideoGenerationAgent < Agent
    include OpenaiConcern

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    MAX_PENDING_GENERATIONS = 50
    PENDING_GENERATION_TTL = 24.hours

    description <<~MD
      The OpenAI Video Generation Agent generates videos using any OpenAI-compatible video generation API (e.g. Sora or compatible services).

      It works with OpenAI's Sora API and any service exposing a compatible `/v1/videos/generations` endpoint.

      Video generation is typically asynchronous. This agent supports two modes of operation:

      ### Modes

      * `submit` - Submit a video generation request and emit an event with the generation ID for later polling.
      * `poll` - Check on a previously submitted generation using its ID and emit the result when complete.
      * `submit_and_poll` - Submit the request and automatically poll until completion (uses agent memory to track status). The agent will re-check on its next scheduled run or when it receives the same event again.

      ### Configuration

      * `api_key` - Your API key (use `{% credential openai_api_key %}`). Falls back to the `OPENAI_API_KEY` environment variable.
      * `base_url` - The API base URL. Defaults to `https://api.openai.com/v1`. Falls back to the `OPENAI_BASE_URL` environment variable.
      * `organization` - (Optional) OpenAI organization ID.
      * `model` - The model to use (e.g. `sora`).
      * `mode` - One of `submit`, `poll`, or `submit_and_poll`.
      * `prompt` - The text prompt describing the video to generate. Supports [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid).
      * `generation_id` - (For `poll` mode) The ID of a previously submitted generation. Supports Liquid: `{{ generation_id }}`.
      * `size` - (Optional) Video resolution, e.g. `1920x1080`, `1280x720`.
      * `duration` - (Optional) Video duration in seconds.
      * `n` - (Optional) Number of videos to generate.
      * `endpoint_path` - (Optional) Override the API endpoint path. Default: `/videos/generations`.
      * `request_timeout` - (Optional) Timeout in seconds for API requests. Default: 60. Max: 600.
      * `output_mode` - (Optional) Set to `merge` to merge the original event payload into the emitted event. Default: `clean`.
      * `expected_receive_period_in_days` - How often you expect events to arrive.

      ### Notes

      The video generation API is evolving. This agent sends the prompt and parameters as-is to the endpoint, so it will work with future API changes by adjusting the options. If your provider uses different endpoint paths, you can override via the `endpoint_path` option.

      When `output_mode` is set to `merge`, the emitted event will contain the original incoming event's payload with the video generation fields merged on top.
    MD

    event_description <<~MD
      **Submit mode** events look like:

          {
            "generation_id": "gen-abc123",
            "status": "pending",
            "prompt": "A cat playing piano",
            "model": "sora"
          }

      **Poll / submit_and_poll mode** events (when complete) look like:

          {
            "generation_id": "gen-abc123",
            "status": "complete",
            "video_url": "https://...",
            "prompt": "A cat playing piano",
            "model": "sora",
            "full_response": { ... }
          }

      If the generation is still in progress, a status event is emitted:

          {
            "generation_id": "gen-abc123",
            "status": "in_progress",
            "prompt": "A cat playing piano",
            "model": "sora"
          }

      Original event contents will be merged when `output_mode` is set to `merge`.
    MD

    def default_options
      {
        'api_key' => '{% credential openai_api_key %}',
        'base_url' => '',
        'organization' => '',
        'model' => 'sora',
        'mode' => 'submit_and_poll',
        'prompt' => '{{ prompt }}',
        'generation_id' => '{{ generation_id }}',
        'size' => '1920x1080',
        'duration' => '',
        'n' => '1',
        'endpoint_path' => '/videos/generations',
        'output_mode' => 'clean',
        'request_timeout' => '60',
        'expected_receive_period_in_days' => '1'
      }
    end

    def validate_options
      validate_openai_options!

      errors.add(:base, "model is required") unless options['model'].present?

      unless %w[submit poll submit_and_poll].include?(options['mode'])
        errors.add(:base, "mode must be 'submit', 'poll', or 'submit_and_poll'")
      end

      if options['mode'] == 'poll'
        errors.add(:base, "generation_id is required for poll mode") unless options['generation_id'].present?
      else
        errors.add(:base, "prompt is required for submit modes") unless options['prompt'].present?
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          case interpolated['mode']
          when 'submit'
            perform_submit(event)
          when 'poll'
            perform_poll(interpolated['generation_id'], event)
          when 'submit_and_poll'
            perform_submit_and_poll(event)
          end
        end
      end
    end

    def check
      case interpolated['mode']
      when 'submit'
        perform_submit
      when 'poll'
        perform_poll(interpolated['generation_id'])
      when 'submit_and_poll'
        check_pending_generations
      end
    end

    private

    def endpoint_path
      interpolated['endpoint_path'].presence || '/videos/generations'
    end

    def perform_submit(event = nil)
      body = build_generation_body
      response = openai_request(:post, endpoint_path, body)
      return if handle_openai_error(response)

      gen_id = response['id'] || response['generation_id']
      status = response['status'] || 'pending'

      create_event payload: openai_base_payload(event).merge(
        'generation_id' => gen_id,
        'status' => status,
        'prompt' => interpolated['prompt'],
        'model' => interpolated['model'],
        'full_response' => response
      )
    end

    def perform_poll(gen_id, event = nil)
      return error("No generation_id provided") unless gen_id.present?

      response = openai_request(:get, "#{endpoint_path}/#{gen_id}")
      return if handle_openai_error(response)

      status = response['status'] || 'unknown'
      payload = {
        'generation_id' => gen_id,
        'status' => status,
        'prompt' => response['prompt'] || interpolated['prompt'],
        'model' => response['model'] || interpolated['model'],
        'full_response' => response
      }

      # Extract video URL(s) from response — handle various API shapes
      if status == 'complete' || status == 'succeeded'
        payload['status'] = 'complete'
        payload['video_url'] = extract_video_url(response)
      end

      create_event payload: openai_base_payload(event).merge(payload)
    end

    def perform_submit_and_poll(event = nil)
      pending = memory['pending_generations'] || []
      if pending.length >= MAX_PENDING_GENERATIONS
        error("Cannot submit: pending generation limit (#{MAX_PENDING_GENERATIONS}) reached. Wait for existing generations to complete.")
        return
      end

      body = build_generation_body
      response = openai_request(:post, endpoint_path, body)
      return if handle_openai_error(response)

      gen_id = response['id'] || response['generation_id']
      status = response['status'] || 'pending'

      if status == 'complete' || status == 'succeeded'
        # Synchronous response — some providers return immediately
        create_event payload: openai_base_payload(event).merge(
          'generation_id' => gen_id,
          'status' => 'complete',
          'prompt' => interpolated['prompt'],
          'model' => interpolated['model'],
          'video_url' => extract_video_url(response),
          'full_response' => response
        )
      else
        # Store pending generation in memory for scheduled polling
        entry = {
          'generation_id' => gen_id,
          'prompt' => interpolated['prompt'],
          'submitted_at' => Time.now.iso8601
        }
        # Preserve original event payload so output_mode merge works during polling
        entry['event_payload'] = event.payload.dup if event && interpolated['output_mode'].to_s == 'merge'

        pending << entry
        update!(memory: memory.merge('pending_generations' => pending))

        create_event payload: openai_base_payload(event).merge(
          'generation_id' => gen_id,
          'status' => status,
          'prompt' => interpolated['prompt'],
          'model' => interpolated['model'],
          'full_response' => response
        )
      end
    end

    def check_pending_generations
      pending = memory['pending_generations'] || []
      return if pending.empty?

      still_pending = []

      pending.each do |gen|
        gen_id = gen['generation_id']

        # Discard entries that have exceeded the TTL
        submitted_at = Time.parse(gen['submitted_at']) rescue nil
        if submitted_at && submitted_at < PENDING_GENERATION_TTL.ago
          error("Video generation #{gen_id} expired after #{PENDING_GENERATION_TTL.inspect} without completing. Discarding.")
          next
        end

        response = openai_request(:get, "#{endpoint_path}/#{gen_id}")

        if response['error']
          handle_openai_error(response)
          still_pending << gen
          next
        end

        status = response['status'] || 'unknown'
        base = gen['event_payload'] ? gen['event_payload'].dup : {}

        if status == 'complete' || status == 'succeeded'
          create_event payload: base.merge(
            'generation_id' => gen_id,
            'status' => 'complete',
            'prompt' => gen['prompt'],
            'model' => interpolated['model'],
            'video_url' => extract_video_url(response),
            'full_response' => response
          )
        elsif status == 'failed' || status == 'error'
          error("Video generation #{gen_id} failed: #{response.dig('error', 'message') || status}")
          create_event payload: base.merge(
            'generation_id' => gen_id,
            'status' => 'failed',
            'prompt' => gen['prompt'],
            'model' => interpolated['model'],
            'full_response' => response
          )
        else
          still_pending << gen
        end
      end

      update!(memory: memory.merge('pending_generations' => still_pending))
    end

    def build_generation_body
      body = {
        'model' => interpolated['model'],
        'prompt' => interpolated['prompt']
      }
      body['n'] = interpolated['n'].to_i if interpolated['n'].present?
      body['size'] = interpolated['size'] if interpolated['size'].present?
      body['duration'] = interpolated['duration'].to_i if interpolated['duration'].present?
      body
    end

    def extract_video_url(response)
      # Handle various response shapes from different providers
      if response['data'].is_a?(Array) && response['data'].first
        response['data'].first['url'] || response['data'].first['video_url']
      elsif response['url']
        response['url']
      elsif response['video_url']
        response['video_url']
      elsif response['output'].is_a?(Hash)
        response['output']['url'] || response['output']['video_url']
      end
    end
  end
end
