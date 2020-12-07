module Agents
  class EmailDigestAgent < Agent
    include EmailConcern

    default_schedule "5am"

    cannot_create_events!

    description <<-MD
      The Email Digest Agent collects any Events sent to it and sends them all via email when scheduled. The number of
      used events also relies on the `Keep events` option of the emitting Agent, meaning that if events expire before
      this agent is scheduled to run, they will not appear in the email.

      By default, the email will have a `subject` and an optional `headline` before listing the Events.  If the Events'
      payloads contain a `message`, that will be highlighted, otherwise everything in
      their payloads will be shown.

      You can specify one or more `recipients` for the email, or skip the option in order to send the email to your
      account's default email address.

      You can provide a `from` address for the email, or leave it blank to default to the value of `EMAIL_FROM_ADDRESS` (`#{ENV['EMAIL_FROM_ADDRESS']}`).

      You can provide a `content_type` for the email and specify `text/plain` or `text/html` to be sent.
      If you do not specify `content_type`, then the recipient email server will determine the correct rendering.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.
    MD

    def default_options
      {
          'subject' => "You have some notifications!",
          'headline' => "Your notifications:",
          'expected_receive_period_in_days' => "2"
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      self.memory['events'] ||= []
      incoming_events.each do |event|
        self.memory['events'] << event.id
      end
    end

    def check
      if self.memory['events'] && self.memory['events'].length > 0
        payloads = received_events.reorder("events.id ASC").where(id: self.memory['events']).pluck(:payload).to_a
        groups = payloads.map { |payload| present(payload) }
        recipients.each do |recipient|
          begin
            SystemMailer.send_message(
              to: recipient,
              from: interpolated['from'],
              subject: interpolated['subject'],
              headline: interpolated['headline'],
              content_type: interpolated['content_type'],
              groups: groups
            ).deliver_now

            log "Sent digest mail to #{recipient}"
          rescue => e
            error("Error sending digest mail to #{recipient}: #{e.message}")
            raise
          end
        end
        self.memory['events'] = []
      end
    end
  end
end
