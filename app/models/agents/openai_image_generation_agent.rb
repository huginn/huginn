module Agents
  class OpenaiImageGenerationAgent < Agent
    include OpenaiConcern

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description <<~MD
      The OpenAI Image Generation Agent generates images using any OpenAI-compatible image generation API (DALL-E 2, DALL-E 3, or compatible services).

      It works with OpenAI and any service exposing a compatible `/v1/images/generations` endpoint.

      ### Configuration

      * `api_key` - Your API key (use `{% credential openai_api_key %}`). Falls back to the `OPENAI_API_KEY` environment variable.
      * `base_url` - The API base URL. Defaults to `https://api.openai.com/v1`. Falls back to the `OPENAI_BASE_URL` environment variable.
      * `organization` - (Optional) OpenAI organization ID.
      * `model` - The model to use (e.g. `dall-e-3`, `dall-e-2`).
      * `prompt` - The text prompt describing the image to generate. Supports [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid).
      * `n` - (Optional) Number of images to generate (1-10, DALL-E 3 only supports 1).
      * `size` - Image size: `256x256`, `512x512`, `1024x1024`, `1792x1024`, or `1024x1792`.
      * `quality` - (DALL-E 3 only) `standard` or `hd`.
      * `style` - (DALL-E 3 only) `vivid` or `natural`.
      * `response_format` - `url` (returns a temporary URL) or `b64_json` (returns base64-encoded image).
      * `request_timeout` - (Optional) Timeout in seconds for API requests. Default: 60. Max: 600.
      * `output_mode` - (Optional) Set to `merge` to merge the original event payload into each emitted event. Default: `clean`.
      * `expected_receive_period_in_days` - How often you expect events to arrive.

      When `output_mode` is set to `merge`, each emitted event will contain the original incoming event's payload with the image generation fields merged on top.
    MD

    event_description <<~MD
      Events look like this (one event per generated image):

          {
            "image_url": "https://...",
            "revised_prompt": "The revised prompt used by the model",
            "prompt": "The original prompt",
            "model": "dall-e-3",
            "size": "1024x1024",
            "index": 0
          }

      When `response_format` is `b64_json`, events include `image_base64` instead of `image_url`:

          {
            "image_base64": "base64-encoded image data",
            "revised_prompt": "...",
            "prompt": "...",
            "model": "dall-e-3",
            "size": "1024x1024",
            "index": 0
          }

      Original event contents will be merged when `output_mode` is set to `merge`.
    MD

    def default_options
      {
        'api_key' => '{% credential openai_api_key %}',
        'base_url' => '',
        'organization' => '',
        'model' => 'dall-e-3',
        'prompt' => '{{ prompt }}',
        'n' => '1',
        'size' => '1024x1024',
        'quality' => 'standard',
        'style' => 'vivid',
        'response_format' => 'url',
        'output_mode' => 'clean',
        'request_timeout' => '60',
        'expected_receive_period_in_days' => '1'
      }
    end

    def validate_options
      validate_openai_options!

      errors.add(:base, "model is required") unless options['model'].present?
      errors.add(:base, "prompt is required") unless options['prompt'].present?

      if options['n'].present? && options['n'].to_i <= 0
        errors.add(:base, "n must be a positive integer")
      end

      if options['size'].present? && !%w[256x256 512x512 1024x1024 1792x1024 1024x1792].include?(options['size'])
        errors.add(:base, "size must be one of: 256x256, 512x512, 1024x1024, 1792x1024, 1024x1792")
      end

      if options['response_format'].present? && !%w[url b64_json].include?(options['response_format'])
        errors.add(:base, "response_format must be 'url' or 'b64_json'")
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          perform_generation(event)
        end
      end
    end

    def check
      perform_generation
    end

    private

    def perform_generation(event = nil)
      body = {
        'model' => interpolated['model'],
        'prompt' => interpolated['prompt']
      }

      body['n'] = interpolated['n'].to_i if interpolated['n'].present?
      body['size'] = interpolated['size'] if interpolated['size'].present?
      body['quality'] = interpolated['quality'] if interpolated['quality'].present?
      body['style'] = interpolated['style'] if interpolated['style'].present?
      body['response_format'] = interpolated['response_format'] if interpolated['response_format'].present?

      response = openai_request(:post, '/images/generations', body)
      return if handle_openai_error(response)

      data = response['data']
      return error("No images returned from API") unless data&.any?

      base = openai_base_payload(event)

      data.each_with_index do |image, index|
        payload = {
          'prompt' => interpolated['prompt'],
          'revised_prompt' => image['revised_prompt'],
          'model' => interpolated['model'],
          'size' => interpolated['size'],
          'index' => index
        }

        if image['url']
          payload['image_url'] = image['url']
        elsif image['b64_json']
          payload['image_base64'] = image['b64_json']
        end

        create_event payload: base.merge(payload)
      end
    end
  end
end
