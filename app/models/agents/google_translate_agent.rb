module Agents
  class GoogleTranslateAgent < Agent
    include FormConfigurable

    cannot_be_scheduled!
    can_dry_run!

    before_validation :parse_json_options

    description <<-MD
      The Google Translate Agent will attempt to translate text between natural languages using Google Translate API.

      This agent can translate several fields at once, see `content` option below.
      You can use [Liquid](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) with `from`, `to` and `content` options.

      Options:

      * `to` - Specify the destination language code. By default this is `en` for English.
      * `from` - Specify the original language code. This is optional, so if empty, the translator service will try to guess the source language.
      * `content` - Specify what you want to translate using JSON. Each field in the JSON object will be translated and the result will be emitted as an event. See examples below.
       * `merge` - If `true` the translated `content` is added to the source event payload under the key `translated_content`, if it is `false` the resulting event will have the structure of `content` field.
      * `expected_receive_period_in_days` is the maximum number of days you would allow to pass between events.

      ### Examples

      Given the following event:

          {
            "data" => {
              "comment" => "Hola Mundo",
              "review" => "Excelente servicio!"
            }
          }

      #### Example 1: Translate a single field without merge.

      Value for `content`:

          {
            "comment" => "{{data.comment}}"
          }

      Output event:

          {
            "comment" => "Hello World"
          }

      #### Example 2: Translate multiple fields with merge `true`.

      Value for `content`:

          {
            "comment" => "{{data.comment}}",
            "feedback" => "{{data.review}}"
          }

      Output event:

          {
            "data" => {
              "comment" => "Hola Mundo",
              "review" => "Excelente servicio!"
            },
            "translated_content" => {
              "comment" => "Hello World",
              "feedback" => "Excellent service!"
            }
          }
    MD

    event_description "User defined"

    form_configurable :from
    form_configurable :to
    form_configurable :content, type: :json, ace: { mode: 'json' }
    form_configurable :merge, type: :array, values: %w(true false)
    form_configurable :expected_receive_period_in_days

    def default_options
      {
        'to' => 'en',
        'expected_receive_period_in_days' => 1,
        'merge' => 'true',
        'content' => {
          'comment' => '{{data.comment}}'
        }
      }
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def validate_options
      errors.add(:base, "The 'to' option is required.") if options['to'].blank?

      if options['expected_receive_period_in_days'].blank?
        errors.add(:base, "The 'expected_receive_period_in_days' option is required.")
      end

      if boolify(options['merge']).nil?
        errors.add(:base, "The 'merge' option must be true or false")
      end
    end

    def translate_event(opts, event = Event.new)
      translated = opts['content'].inject({}) do |t, kv|
        text = translate(kv.last, opts['from'], opts['to'])
        t.merge(kv.first => text)
      end

      if boolify(opts['merge'])
        data = event.payload.merge({ translated_content: translated })
        return create_event(payload: data)
      end

      create_event(payload: translated)
    end

    def check
      translate_event(interpolated)
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        translate_event(interpolated(event), event)
      end
    end

    private

    def translate(text, from, to)
      translator.translate(text, from: from.presence, to: to, model: :nmt).text
    end

    def translator
      @translator ||= Google::Cloud::Translate.new(key: ENV['GOOGLE_TRANSLATE_API_KEY'])
    end

    def parse_json_options
      parse_json_option('content')
    end

    def parse_json_option(key)
      options[key] = JSON.parse(options[key]) unless options[key].is_a?(Hash)
    rescue
      errors.add(:base, "The '#{key}' option is an invalid JSON.")
    end
  end
end
