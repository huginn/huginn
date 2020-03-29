module Agents
  class EmailAgent < Agent
    include EmailConcern

    can_dry_run!
    cannot_be_scheduled!
    cannot_create_events!
    no_bulk_receive!

    description <<-MD
      The Email Agent sends any events it receives via email immediately.

      You can specify the email's subject line by providing a `subject` option, which can contain [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) formatting.  E.g.,
      you could provide `"Huginn email"` to set a simple subject, or `{{subject}}` to use the `subject` key from the incoming Event.

      By default, the email body will contain an optional `headline`, followed by a listing of the Events' keys.

      You can customize the email body by including the optional `body` param.  Like the `subject`, the `body` can be a simple message
      or a Liquid template.  You could send only the Event's `some_text` field with a `body` set to `{{ some_text }}`.
      The body can contain simple HTML and will be sanitized. Note that when using `body`, it will be wrapped with `<html>` and `<body>` tags,
      so you do not need to add these yourself.

      You can specify one or more `recipients` for the email, or skip the option in order to send the email to your
      account's default email address.

      You can provide a `from` address for the email, or leave it blank to default to the value of `EMAIL_FROM_ADDRESS` (`#{ENV['EMAIL_FROM_ADDRESS']}`).

      You can provide a `content_type` for the email and specify `text/plain` or `text/html` to be sent.
      If you do not specify `content_type`, then the recipient email server will determine the correct rendering.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.
    MD

    def default_options
      {
          'subject' => "You have a notification!",
          'headline' => "Your notification:",
          'expected_receive_period_in_days' => "2"
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        recipients(event.payload).each do |recipient|
          begin
            SystemMailer.send_message(
              to: recipient,
              from: interpolated(event)['from'],
              subject: interpolated(event)['subject'],
              headline: interpolated(event)['headline'],
              body: interpolated(event)['body'],
              content_type: interpolated(event)['content_type'],
              groups: [present(event.payload)]
            ).deliver_now
            log "Sent mail to #{recipient} with event #{event.id}"
          rescue => e
            error("Error sending mail to #{recipient} with event #{event.id}: #{e.message}")
            raise
          end
        end
      end
    end
  end
end
