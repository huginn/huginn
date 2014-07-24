module Agents
  class PushbulletAgent < Agent
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

      In every value of the options hash you can use the liquid templating, learn more about it at the [Wiki](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid).
    MD

    def default_options
      {
        'api_key' => '',
        'device_id' => '',
        'title' => "Hello from Huginn!",
        'body' => '{{body}}',
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
      mo = interpolated(event)
      {
        :basic_auth => {:username => mo[:api_key], :password => ''},
        :body => {:device_iden => mo[:device_id], :title => mo[:title], :body => mo[:body], :type => 'note'}
      }
    end
  end
end
