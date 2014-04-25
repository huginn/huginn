module Agents
  class HipchatAgent < Agent
    cannot_be_scheduled!
    cannot_create_events!

    description <<-MD
      The HipchatAgent sends messages to a Hipchat Room

      To authenticate you need to set the `auth_token`, you can get one at your Hipchat Group Admin page which you can find here:

      `https://`yoursubdomain`.hipchat.com/admin/api`

      Change the `room_name` to the name of the room you want to send notifications to.

      You can provide a `username` and a `message`. When sending a HTML formatted message change `format` to "html".
      If you want your message to notify the room members change `notify` to "true".
      Modify the background color of your message via the `color` attribute (one of "yellow", "red", "green", "purple", "gray", or "random")

      If you want to specify either of those attributes per event, you can provide a [JSONPath](http://goessner.net/articles/JsonPath/) for each of them (except the `auth_token`).
    MD

    def default_options
      {
        'auth_token' => '',
        'room_name' => '',
        'room_name_path' => '',
        'username' => "Huginn",
        'username_path' => '',
        'message' => "Hello from Huginn!",
        'message_path' => '',
        'notify' => false,
        'notify_path' => '',
        'color' => 'yellow',
        'color_path' => '',
      }
    end

    def validate_options
      errors.add(:base, "you need to specify a hipchat auth_token") unless options['auth_token'].present?
      errors.add(:base, "you need to specify a room_name or a room_name_path") if options['room_name'].blank? && options['room_name_path'].blank?
    end

    def working?
      (last_receive_at.present? && last_error_log_at.nil?) || (last_receive_at.present? && last_error_log_at.present? && last_receive_at > last_error_log_at)
    end

    def receive(incoming_events)
      client = HipChat::Client.new(options[:auth_token])
      incoming_events.each do |event|
        mo = merge_options event
        client[mo[:room_name]].send(mo[:username], mo[:message], :notify => mo[:notify].to_s == 'true' ? 1 : 0, :color => mo[:color])
      end
    end

    private
    def select_option(event, a)
      if options[a.to_s + '_path'].present?
        Utils.value_at(event.payload, options[a.to_s + '_path'])
      else
        options[a]
      end
    end

    def options_with_path
      [:room_name, :username, :message, :notify, :color]
    end

    def merge_options event
      options.select { |k, v| options_with_path.include? k}.tap do |merged_options|
        options_with_path.each do |a|
          merged_options[a] = select_option(event, a)
        end
      end
    end
  end
end
