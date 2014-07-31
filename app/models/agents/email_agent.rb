module Agents
  class EmailAgent < Agent
    include EmailConcern

    cannot_be_scheduled!
    cannot_create_events!

    description <<-MD
      The EmailAgent sends any events it receives via email immediately.

      The email will have a `subject` and an optional `headline` before listing the Events.  If the Events' payloads
      contain a `:message`, that will be highlighted, otherwise everything in their payloads will be shown.

      You can specify one or more `recipients` for the email, or skip the option in order to send the email to your
      account's default email address.

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
        recipients(event.payload).each do |recipient|
          SystemMailer.delay.send_message(:to => recipient, :subject => interpolated(event)['subject'], :headline => interpolated(event)['headline'], :groups => [present(event.payload)])
        end
      end
    end
  end
end
