module Agents
  class GoogleTranslationAgent < Agent
    cannot_be_scheduled!

    gem_dependency_check { defined?(Google) && defined?(Google::Cloud::Translate) }

    description <<-MD
      The Translation Agent will attempt to translate text between natural languages.

      #{'## Include `google-api-client` in your Gemfile to use this Agent!' if dependencies_missing?}

      Services are provided using Google Translate. You can [sign up](https://cloud.google.com/translate/) to get `google_api_key` which is required to use this agent.
      The service is **not free**.

      To use credentials for the `google_api_key` use the liquid `credential` tag like so `{% credential google-api-key %}`

      `to` must be filled with a [translator language code](https://cloud.google.com/translate/docs/languages).

      `from` is the language translated from. If it's not specified, the API will attempt to detect the source language automatically and return it within the response.

      Specify what you would like to translate in `content` field, you can use [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) specify which part of the payload you want to translate.

      `expected_receive_period_in_days` is the maximum number of days you would allow to pass between events.
    MD

    event_description "User defined"

    def default_options
      {
        'to' => "sv",
        'from' => 'en',
        'google_api_key' => '',
        'expected_receive_period_in_days' => 1,
        'content' => {
          'text' => "{{message}}",
          'moretext' => "{{another message}}"
        }
      }
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def validate_options
      unless options['google_api_key'].present? && options['to'].present? && options['content'].present? && options['expected_receive_period_in_days'].present?
        errors.add :base, "google_api_key, to, content and expected_receive_period_in_days are all required"
      end
    end

    def translate_from
      interpolated["from"].presence
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        translated_event = {}
        opts = interpolated(event)
        opts['content'].each_pair do |key, value|
          result = translate(value)
          translated_event[key] = result.text
        end
        create_event payload: translated_event
      end
    end

    def google_client
      @google_client ||= Google::APIClient.new(
        {
          application_name: "Huginn",
          application_version: "0.0.1",
          key: options['google_api_key'],
          authorization: nil
        }
      )
    end

    def translate_service
      @translate_service ||= google_client.discovered_api('translate','v2')
    end

    def cloud_translate_service
      # https://github.com/GoogleCloudPlatform/google-cloud-ruby/blob/master/google-cloud-translate/lib/google-cloud-translate.rb#L130
      @google_client ||= Google::Cloud::Translate.new(key: interpolated['google_api_key'])
    end

    def translate(value)
      # google_client.execute(
      #   api_method: translate_service.translations.list,
      #   parameters: {
      #     format: 'text',
      #     source: translate_from,
      #     target: options["to"],
      #     q: value
      #   }
      # )
      cloud_translate_service.translate(value, to: interpolated["to"], from: translate_from, format: "text")
    end
  end
end
