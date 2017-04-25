require 'google/apis/translate_v2'

module Agents
  class GoogleTranslationAgent < Agent
    cannot_be_scheduled!

    description <<-MD
      The Translation Agent will attempt to translate text between natural languages.

      Services are provided using Google Translate. You can [sign up](https://cloud.google.com/translate/) to get `google_api_key` which is required to use this agent.

      `to` must be filled with a [translator language code](https://cloud.google.com/translate/docs/languages).

      `from` is the language translated from. If it's not specified, the API will attempt to detect the source language automatically and return it within the response.

      Specify what you would like to translate in `content` field, you can use [Liquid](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) specify which part of the payload you want to translate.

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
      interpolated["from"].presence || 'en'
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        translated_event = {}
        opts = interpolated(event)
        opts['content'].each_pair do |key, value|
          result = translate_service.list_translations(value, opts['to'], source: translate_from)
          translated_event[key] = result.translations.last.translated_text
        end
        create_event payload: translated_event
      end
    end

    def translate_service
      @translate_service ||= Google::Apis::TranslateV2::TranslateService.new.tap {|service| service.key = options['google_api_key']}
    end
  end
end
