module Agents
  class PushbulletAgent < Agent
    include JsonPathOptionsOverwritable

    cannot_be_scheduled!
    cannot_create_events!

    description <<-MD
      The Pushbullet agent sends pushes to a pushbullet device

      To authenticate you need to set the `api_key`, you can find yours at your account page:

      `https://www.pushbullet.com/account`

      Currently you need to get a the device identification manually:

      `curl -u <your api key here>: https://api.pushbullet.com/api/devices`

      Put one of the retured `iden` strings into the `device_id` field.

      You can provide a `title` and a `body`.

      If you want to specify `title` or `body` per event, you can provide a [JSONPath](http://goessner.net/articles/JsonPath/) for each of them.
    MD

    def default_options
      {
        'api_key' => '',
        'device_id' => '',
        'title' => "Hello from Huginn!",
        'title_path' => '',
        'body' => '',
        'body_path' => '',
      }
    end

    def validate_options
      errors.add(:base, "you need to specify a pushbullet api_key") unless options['api_key'].present?
      errors.add(:base, "you need to specify a device_id") if options['device_id'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        response = HTTParty.post "https://api.pushbullet.com/api/pushes", query_options(event)
        error(response.body) if response.body.include? 'error'
      end
    end

    private
    def query_options(event)
      mo = merge_json_path_options event
      basic_options.deep_merge(:body => {:title => mo[:title], :body => mo[:body]})
    end

    def basic_options
      {:basic_auth => {:username =>options[:api_key], :password=>''}, :body => {:device_iden => options[:device_id], :type => 'note'}}
    end

    def options_with_path
      [:title, :body]
    end
  end
end
