module Agents
  class TranslationAgent < Agent
    cannot_be_scheduled!

    description <<-MD
      The Translation Agent will attempt to translate text between natural languages.

      Services are provided using Microsoft Translator. You can [sign up](https://datamarket.azure.com/dataset/bing/microsofttranslator) and [register your application](https://datamarket.azure.com/developer/applications/register) to get `client_id` and `client_secret` which are required to use this agent.
      
      `to` must be filled with a [translator language code](http://msdn.microsoft.com/en-us/library/hh456380.aspx).

      Specify what you would like to translate in `content` field, you can use [Liquid](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) specify which part of the payload you want to translate.

      `expected_receive_period_in_days` is the maximum number of days you would allow to pass between events.
    MD

    event_description "User defined"

    def default_options
      {
        'client_id' => "xxxxxx",
        'client_secret' => "xxxxxx",
        'to' => "fi",
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

    def translate(text, to, access_token)
      translate_uri = URI 'http://api.microsofttranslator.com/v2/Ajax.svc/Translate'
      params = {
        'text' => text,
        'to' => to
      }
      translate_uri.query = URI.encode_www_form params
      request = Net::HTTP::Get.new translate_uri.request_uri
      request['Authorization'] = "Bearer" + " " + access_token
      http = Net::HTTP.new translate_uri.hostname, translate_uri.port
      response = http.request request
      YAML.load response.body
    end

    def validate_options
      unless options['client_id'].present? && options['client_secret'].present? && options['to'].present? && options['content'].present? && options['expected_receive_period_in_days'].present?
        errors.add :base, "client_id,client_secret,to,expected_receive_period_in_days and content are all required"
      end
    end

    def postform(uri, params)
      req = Net::HTTP::Post.new(uri.request_uri)
      req.form_data = params
      Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) { |http| http.request(req) }
    end

    def receive(incoming_events)
      auth_uri = URI "https://datamarket.accesscontrol.windows.net/v2/OAuth2-13"
      response = postform auth_uri, :client_id => interpolated['client_id'],
                                    :client_secret => interpolated['client_secret'],
                                    :scope => "http://api.microsofttranslator.com",
                                    :grant_type => "client_credentials"
      access_token = JSON.parse(response.body)["access_token"]
      incoming_events.each do |event|
        translated_event = {}
        opts = interpolated(event)
        opts['content'].each_pair do |key, value|
          translated_event[key] = translate(value.first, opts['to'], access_token)
        end
        create_event :payload => translated_event
      end
    end
  end
end
