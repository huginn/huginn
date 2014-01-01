module Agents
  class EmailAgent < Agent
    include EmailConcern

    cannot_be_scheduled!
    cannot_create_events!

    description <<-MD
      The EmailAgent sends any events it receives via email immediately.
      The email will be sent to your account's address and will have a `subject` and an optional `headline` before
      listing the Events.  If the Events' payloads contain a `:message`, that will be highlighted, otherwise everything in
      their payloads will be shown.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.
    MD

    def default_options
      {
          'subject' => "You have a notification!",
          'headline' => "Your notification:",
          'expected_receive_period_in_days' => "2"
      }
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        log "Sending digest mail to #{user.email} with event #{event.id}"
        SystemMailer.delay.send_message(:to => user.email, :subject => options['subject'], :headline => options['headline'], :groups => [present(event.payload)])
      end
    end
  end
end
