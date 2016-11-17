require 'google/apis/translate_v2'

module Agents
  class GoogleTranslationAgent < Agent
    cannot_be_scheduled!

    description <<-MD
      The Translation Agent will attempt to translate text between natural languages.

      Services are provided using Google Translate. You can [sign up](https://cloud.google.com/translate/) and [register your application](https://datamarket.azure.com/developer/applications/register) to get `client_id` and `client_secret` which are required to use this agent.

    MD

    event_description "User defined"

    def default_options
      {
        'to' => "sv",
        'from' => 'en',
        'expected_receive_period_in_days' => 1,
        'content' => {
          'text' => "{{message.text}}",
          'content' => "{{xyz}}"
        }
      }
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def validate_options
      unless ENV['GOOGLE_API_KEY'].present? && options['to'].present? && options['content'].present? && options['expected_receive_period_in_days'].present?
        errors.add :base, "GOOGLE_API_KEY, to,expected_receive_period_in_days and content are all required"
      end
    end

    def translate_from
      interpolated["from"].presence || 'en'
    end

    def receive(incoming_events)
      translate = Google::Apis::TranslateV2::TranslateService.new
      translate.key = ENV['GOOGLE_API_KEY']
      incoming_events.each do |event|
        translated_event = {}
        opts = interpolated(event)
        opts['content'].each_pair do |key, value|
          result = translate.list_translations(value, opts['to'], source: translate_from)
          translated_event[key] = result.translations.last.translated_text
        end
        create_event :payload => translated_event
      end
    end
  end
end
