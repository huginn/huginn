module Agents
  class JabberAgent < Agent
    include LiquidInterpolatable

    cannot_be_scheduled!
    cannot_create_events!

    description <<-MD
      The JabberAgent will send any events it receives to your Jabber/XMPP IM account.

      Specify the `jabber_server` and `jabber_port` for your Jabber server.

      The `message` is sent from `jabber_sender` to `jaber_receiver`. This message
      can contain any keys found in the source's payload, escaped using double curly braces.
      ex: `"News Story: {{title}}: {{url}}"`

      Have a look at the [Wiki](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) to learn more about liquid templating.
    MD

    def default_options
      {
        'jabber_server'   => '127.0.0.1',
        'jabber_port'     => '5222',
        'jabber_sender'   => 'huginn@localhost',
        'jabber_receiver' => 'muninn@localhost',
        'jabber_password' => '',
        'message'         => 'It will be {{temp}} out tomorrow',
        'expected_receive_period_in_days' => "2"
      }
    end

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        log "Sending IM to #{options['jabber_receiver']} with event #{event.id}"
        deliver body(event)
      end
    end

    def validate_options
      errors.add(:base, "server and username is required") unless credentials_present?
    end

    def deliver(text)
      client.send Jabber::Message::new(options['jabber_receiver'], text).set_type(:chat)
    end

    private

    def client
      Jabber::Client.new(Jabber::JID::new(options['jabber_sender'])).tap do |sender|
        sender.connect(options['jabber_server'], (options['jabber_port'] || '5222'))
        sender.auth(options['jabber_password'])
      end
    end

    def credentials_present?
      options['jabber_server'].present? && options['jabber_sender'].present? && options['jabber_receiver'].present?
    end

    def body(event)
      interpolate_string(options['message'], event.payload)
    end
  end
end
