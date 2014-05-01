module Agents
  class HipchatAgent < Agent
    include LiquidInterpolatable

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

      Have a look at the [Wiki](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) to learn more about liquid templating.
    MD

    def default_options
      {
        'auth_token' => '',
        'room_name' => '',
        'username' => "Huginn",
        'message' => "Hello from Huginn!",
        'notify' => false,
        'color' => 'yellow',
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
        mo = interpolate_options options, event.payload
        client[mo[:room_name]].send(mo[:username], mo[:message], :notify => mo[:notify].to_s == 'true' ? 1 : 0, :color => mo[:color])
      end
    end
  end
end
