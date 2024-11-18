module Agents
  class GoogleTranslationAgent < Agent
    cannot_be_scheduled!
    can_dry_run!

    gem_dependency_check do
      require 'google/cloud/translate/v2'
    rescue LoadError
      false
    else
      true
    end

    description <<~MD
      The Translation Agent will attempt to translate text between natural languages.

      #{'## Include `google-api-client` in your Gemfile to use this Agent!' if dependencies_missing?}

      Services are provided using Google Translate. You can [sign up](https://cloud.google.com/translate/) to get `google_api_key` which is required to use this agent.
      The service is **not free**.

      To use credentials for the `google_api_key` use the liquid `credential` tag like so `{% credential google-api-key %}`

      `to` must be filled with a [translator language code](https://cloud.google.com/translate/docs/languages).

      `from` is the language translated from. If it's not specified, the API will attempt to detect the source language automatically and return it within the response.

      Specify an object in `content` field using [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) expressions, which will be evaluated for each incoming event, and then translated to become the payload of the new event.
      You can specify a nested object of any levels containing arrays and objects, and all string values except for object keys will be recursively translated.

      Set `mode` to `merge` if you want to merge each translated content with the original event payload.  The default behavior (`clean`) is to emit events with only translated contents.

      `expected_receive_period_in_days` is the maximum number of days you would allow to pass between events.
    MD

    event_description "User defined"

    def default_options
      {
        'mode' => 'clean',
        'to' => 'sv',
        'from' => 'en',
        'google_api_key' => '',
        'expected_receive_period_in_days' => 1,
        'content' => {
          'text' => "{{message}}",
          'moretext' => "{{another_message}}"
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

      case options['mode'].presence
      when nil, /\A(?:clean|merge)\z|\{/
        # ok
      else
        errors.add(:base, "mode must be 'clean' or 'merge'")
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          translated_content = translate(interpolated['content'])

          case interpolated['mode']
          when 'merge'
            create_event payload: event.payload.merge(translated_content)
          else
            create_event payload: translated_content
          end
        end
      end
    end

    def translate(content)
      if !content.is_a?(Hash)
        error("content must be an object, but it is #{content.class}.")
        return
      end

      api = Google::Cloud::Translate::V2.new(
        key: interpolated['google_api_key']
      )

      texts = []
      walker = ->(value) {
        case value
        in nil | Numeric | true | false
        in _ if _.blank?
        in String
          texts << value
        in Array
          value.each(&walker)
        in Hash
          value.each_value(&walker)
        end
      }
      walker.call(content)

      translations =
        if texts.empty?
          []
        else
          api.translate(
            *texts,
            from: interpolated['from'].presence,
            to: interpolated['to'],
            format: 'text',
          )
        end

      # Hash key order should be constant in Ruby
      mapper = ->(value) {
        case value
        in nil | Numeric | true | false
          value
        in _ if _.blank?
          value
        in String
          translations&.shift&.text
        in Array
          value.map(&mapper)
        in Hash
          value.transform_values(&mapper)
        end
      }
      mapper.call(content)
    end
  end
end
