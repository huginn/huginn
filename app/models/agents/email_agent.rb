module Agents
  class EmailAgent < Agent
    include EmailConcern

    cannot_be_scheduled!
    cannot_create_events!

    description <<-MD
      The EmailAgent sends any events it receives via email immediately.

      You can specify the email's subject line by providing a `subject` option, which can contain Liquid formatting.  E.g.,
      you could provide `"Huginn email"` to set a simple subject, or `{{subject}}` to use the `subject` key from the incoming Event.

      By default, the email body will contain an optional `headline`, followed by a listing of the Events' keys.

      You can customize the email body by including the optional `body` param.  Like the `subject`, the `body` can be a simple message
      or a Liquid template.  You could send only the Event's `some_text` field with a `body` set to `{{ some_text }}`.
      The body can contain simple HTML and will be sanitized.

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
          SystemMailer.send_message(:to => recipient, :subject => interpolated(event)['subject'], :headline => interpolated(event)['headline'], :body => interpolated(event)['body'], :groups => [present(event.payload)]).deliver_later
        end
      end
    end
  end
end
