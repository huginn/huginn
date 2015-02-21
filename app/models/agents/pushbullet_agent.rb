module Agents
  class PushbulletAgent < Agent
    include FormConfigurable

    cannot_be_scheduled!
    cannot_create_events!

    API_URL = 'https://api.pushbullet.com/v2/pushes'
    TYPE_TO_ATTRIBUTES = {
            'note'    => [:title, :body],
            'link'    => [:title, :body, :url],
            'address' => [:name, :address]
    }

    description <<-MD
      The Pushbullet agent sends pushes to a pushbullet device

      To authenticate you need to set the `api_key`, you can find yours at your account page:

      `https://www.pushbullet.com/account`

      Currently you need to get a the device identification manually:

      `curl -u <your api key here>: https://api.pushbullet.com/v2/devices`

      To register a new device run the following command:

      `curl -u <your api key here>: -X POST https://api.pushbullet.com/v2/devices -d nickname=huginn -d type=stream`

      Put one of the retured `iden` strings into the `device_id` field.

      You have to provide a message `type` which has to be `note`, `link`, or `address`. The message types `checklist`, and `file` are not supported at the moment.

      Depending on the message `type` you can use additional fields:

      * note: `title` and `body`
      * link: `title`, `body`, and `url`
      * address: `name`, and `address`

      In every value of the options hash you can use the liquid templating, learn more about it at the [Wiki](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid).
    MD

    def default_options
      {
        'api_key' => '',
        'device_id' => '',
        'title' => "{{title}}",
        'body' => '{{body}}',
        'type' => 'note',
      }
    end

    form_configurable :api_key
    form_configurable :device_id
    form_configurable :type, type: :array, values: ['note', 'link', 'address']
    form_configurable :title
    form_configurable :body, type: :text
    form_configurable :url
    form_configurable :name
    form_configurable :address

    def validate_options
      errors.add(:base, "you need to specify a pushbullet api_key") if options['api_key'].blank?
      errors.add(:base, "you need to specify a device_id") if options['device_id'].blank?
      errors.add(:base, "you need to specify a valid message type") if options['type'].blank? or not ['note', 'link', 'address'].include?(options['type'])
      TYPE_TO_ATTRIBUTES[options['type']].each do |attr|
        errors.add(:base, "you need to specify '#{attr.to_s}' for the type '#{options['type']}'") if options[attr].blank?
      end
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        response = HTTParty.post API_URL, query_options(event)
        error(response.body) if response.body.include? 'error'
      end
    end

    private
    def query_options(event)
      mo = interpolated(event)
      {
        basic_auth: {username: mo[:api_key], password: ''},
        body: {device_iden: mo[:device_id], type: mo[:type]}.merge(payload(mo))
      }
    end

    def payload(mo)
      Hash[TYPE_TO_ATTRIBUTES[mo[:type]].map { |k| [k, mo[k]] }]
    end
  end
end
