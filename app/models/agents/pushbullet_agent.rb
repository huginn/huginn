module Agents
  class PushbulletAgent < Agent
    include FormConfigurable

    cannot_be_scheduled!
    cannot_create_events!
    no_bulk_receive!

    before_validation :create_device, on: :create

    API_BASE = 'https://api.pushbullet.com/v2/'
    TYPE_TO_ATTRIBUTES = {
            'note'    => [:title, :body],
            'link'    => [:title, :body, :url],
            'address' => [:name, :address]
    }
    class Unauthorized < StandardError; end

    description <<-MD
      The Pushbullet agent sends pushes to a pushbullet device

      To authenticate you need to either the `api_key` or create a `pushbullet_api_key` credential, you can find yours at your account page:

      `https://www.pushbullet.com/account`

      If you do not select an existing device, Huginn will create a new one with the name 'Huginn'.

      To push to all of your devices, select `All Devices` from the devices list.

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

    form_configurable :api_key, roles: :validatable
    form_configurable :device_id, roles: :completable
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

    def validate_api_key
      devices
      true
    rescue Unauthorized
      false
    end

    def complete_device_id
      devices
        .map { |d| {text: d['nickname'], id: d['iden']} }
        .unshift(text: 'All Devices', id: '__ALL__')
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        safely do
          response = request(:post, 'pushes', query_options(event))
        end
      end
    end

    private
    def safely
      yield
    rescue Unauthorized => e
      error(e.message)
    end

    def request(http_method, method, options)
      response = JSON.parse(HTTParty.send(http_method, API_BASE + method, options).body)
      raise Unauthorized, response['error']['message'] if response['error'].present?
      response
    end

    def devices
      response = request(:get, 'devices', basic_auth)
      response['devices'].select { |d| d['pushable'] == true }
    rescue Unauthorized
      []
    end

    def create_device
      return if options['device_id'].present?
      safely do
        response = request(:post, 'devices', basic_auth.merge(body: {nickname: 'Huginn', type: 'stream'}))
        self.options[:device_id] = response['iden']
      end
    end

    def basic_auth
      {basic_auth: {username: interpolated[:api_key].presence || credential('pushbullet_api_key'), password: ''}}
    end

    def query_options(event)
      mo = interpolated(event)
      dev_ident = mo[:device_id] == "__ALL__" ? '' : mo[:device_id]
      basic_auth.merge(body: {device_iden: dev_ident, type: mo[:type]}.merge(payload(mo)))
    end

    def payload(mo)
      Hash[TYPE_TO_ATTRIBUTES[mo[:type]].map { |k| [k, mo[k]] }]
    end
  end
end
