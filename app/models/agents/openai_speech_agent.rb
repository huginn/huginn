module Agents
  class OpenaiSpeechAgent < Agent
    include OpenaiConcern
    include FileHandling

    consumes_file_pointer!

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description <<~MD
      The OpenAI Speech Agent provides both **speech-to-text** (Whisper) and **text-to-speech** (TTS) capabilities using any OpenAI-compatible API.

      It works with OpenAI, Azure OpenAI, and any other service exposing compatible `/v1/audio/transcriptions`, `/v1/audio/translations`, or `/v1/audio/speech` endpoints.

      ### Modes

      Set `mode` to one of:

      * `transcribe` - Convert audio to text using the Whisper API (`/v1/audio/transcriptions`). Requires an audio file via `audio_url` or an incoming event with a `file_pointer`.
      * `translate` - Translate audio to English text using the Whisper API (`/v1/audio/translations`). Same input requirements as `transcribe`.
      * `speak` - Convert text to audio using the TTS API (`/v1/audio/speech`). Requires `input_text`.

      ### Configuration

      * `api_key` - Your API key (use `{% credential openai_api_key %}`). Falls back to the `OPENAI_API_KEY` environment variable.
      * `base_url` - The API base URL. Defaults to `https://api.openai.com/v1`. Falls back to the `OPENAI_BASE_URL` environment variable.
      * `organization` - (Optional) OpenAI organization ID.
      * `mode` - One of `transcribe`, `translate`, or `speak`.
      * `model` - The model to use. For transcription/translation: `whisper-1`. For TTS: `tts-1` or `tts-1-hd`.
      * `audio_url` - (For transcribe/translate) URL of the audio file to process. Supports [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid).
      * `input_text` - (For speak) The text to convert to speech. Supports Liquid.
      * `voice` - (For speak) The voice to use: `alloy`, `echo`, `fable`, `onyx`, `nova`, or `shimmer`.
      * `response_format` - (Optional) For transcription: `json`, `text`, `srt`, `verbose_json`, or `vtt`. For TTS: `mp3`, `opus`, `aac`, `flac`, or `pcm`.
      * `language` - (Optional, transcribe only) ISO-639-1 language code to improve accuracy.
      * `request_timeout` - (Optional) Timeout in seconds for API requests. Default: 60. Max: 600.
      * `output_mode` - (Optional) Set to `merge` to merge the original event payload into the emitted event. Default: `clean`.
      * `expected_receive_period_in_days` - How often you expect events to arrive.

      When `output_mode` is set to `merge`, the emitted event will contain the original incoming event's payload with the speech/transcription fields merged on top.
    MD

    event_description <<~MD
      **Transcribe/Translate mode** events look like:

          {
            "text": "The transcribed or translated text",
            "language": "en",
            "duration": 5.2,
            "full_response": { ... }
          }

      **Speak mode** events look like:

          {
            "audio_base64": "base64-encoded audio data",
            "content_type": "audio/mpeg",
            "model": "tts-1",
            "voice": "alloy",
            "input_text": "The original text"
          }

      Original event contents will be merged when `output_mode` is set to `merge`.
    MD

    def default_options
      {
        'api_key' => '{% credential openai_api_key %}',
        'base_url' => '',
        'organization' => '',
        'mode' => 'transcribe',
        'model' => 'whisper-1',
        'audio_url' => '{{ audio_url }}',
        'input_text' => '{{ text }}',
        'voice' => 'alloy',
        'response_format' => 'json',
        'language' => '',
        'output_mode' => 'clean',
        'request_timeout' => '60',
        'expected_receive_period_in_days' => '1'
      }
    end

    def validate_options
      validate_openai_options!

      errors.add(:base, "model is required") unless options['model'].present?

      unless %w[transcribe translate speak].include?(options['mode'])
        errors.add(:base, "mode must be 'transcribe', 'translate', or 'speak'")
      end

      if options['mode'] == 'speak'
        errors.add(:base, "input_text is required for speak mode") unless options['input_text'].present?
        errors.add(:base, "voice is required for speak mode") unless options['voice'].present?
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          case interpolated['mode']
          when 'transcribe'
            perform_transcription(event)
          when 'translate'
            perform_translation(event)
          when 'speak'
            perform_speech(event)
          end
        end
      end
    end

    def check
      case interpolated['mode']
      when 'transcribe'
        perform_transcription
      when 'translate'
        perform_translation
      when 'speak'
        perform_speech
      end
    end

    private

    def perform_transcription(event = nil)
      audio_data = fetch_audio(event)
      return unless audio_data

      form_data = {
        'file' => audio_data,
        'model' => interpolated['model']
      }
      form_data['language'] = interpolated['language'] if interpolated['language'].present?
      form_data['response_format'] = interpolated['response_format'] if interpolated['response_format'].present?

      response = openai_multipart_request('/audio/transcriptions', form_data)
      return if handle_openai_error(response)

      create_event payload: openai_base_payload(event).merge(
        'text' => response['text'],
        'language' => response['language'],
        'duration' => response['duration'],
        'full_response' => response
      )
    end

    def perform_translation(event = nil)
      audio_data = fetch_audio(event)
      return unless audio_data

      form_data = {
        'file' => audio_data,
        'model' => interpolated['model']
      }
      form_data['response_format'] = interpolated['response_format'] if interpolated['response_format'].present?

      response = openai_multipart_request('/audio/translations', form_data)
      return if handle_openai_error(response)

      create_event payload: openai_base_payload(event).merge(
        'text' => response['text'],
        'language' => 'en',
        'duration' => response['duration'],
        'full_response' => response
      )
    end

    def perform_speech(event = nil)
      body = {
        'model' => interpolated['model'],
        'input' => interpolated['input_text'],
        'voice' => interpolated['voice']
      }
      body['response_format'] = interpolated['response_format'] if interpolated['response_format'].present?

      response = openai_raw_request(:post, '/audio/speech', body)
      return if response.nil?

      if response.status >= 400
        begin
          error_body = JSON.parse(response.body)
          return if handle_openai_error(error_body)
        rescue JSON::ParserError
          error("TTS API error (HTTP #{response.status}): #{response.body.truncate(500)}")
          return
        end
      end

      content_type = response.headers['content-type'] || 'audio/mpeg'
      audio_base64 = Base64.strict_encode64(response.body)

      create_event payload: openai_base_payload(event).merge(
        'audio_base64' => audio_base64,
        'content_type' => content_type,
        'model' => interpolated['model'],
        'voice' => interpolated['voice'],
        'input_text' => interpolated['input_text']
      )
    end

    def fetch_audio(event = nil)
      if event && has_file_pointer?(event)
        io = get_io(event)
        filename = event.payload.dig('file_pointer', 'file') || 'audio.wav'
        return Faraday::UploadIO.new(io, MIME::Types.type_for(filename).first&.content_type || 'audio/wav', filename)
      end

      audio_url = interpolated['audio_url']
      unless audio_url.present?
        error("No audio source provided. Set audio_url or send an event with a file_pointer.")
        return nil
      end

      response = openai_raw_connection.get(audio_url)
      if response.status >= 400
        error("Failed to fetch audio from #{audio_url}: HTTP #{response.status}")
        return nil
      end

      content_type = response.headers['content-type'] || 'audio/wav'
      extension = MIME::Types[content_type].first&.preferred_extension || 'wav'
      io = StringIO.new(response.body)
      Faraday::UploadIO.new(io, content_type, "audio.#{extension}")
    end
  end
end
