module Agents
  class DigestEmailAgent < Agent
    include EmailConcern

    default_schedule "5am"

    cannot_create_events!

    description <<-MD
      The DigestEmailAgent collects any Events sent to it and sends them all via email when run.
      The email will be sent to your account's address and will have a `subject` and an optional `headline` before
      listing the Events.  If the Events' payloads contain a `message`, that will be highlighted, otherwise everything in
      their payloads will be shown.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.
    MD

    def default_options
      {
          'subject' => "You have some notifications!",
          'headline' => "Your notifications:",
          'expected_receive_period_in_days' => "2"
      }
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        self.memory['queue'] ||= []
        self.memory['queue'] << event.payload
        self.memory['events'] ||= []
        self.memory['events'] << event.id
      end
    end

    def check
      if self.memory['queue'] && self.memory['queue'].length > 0
        ids = self.memory['events'].join(",")
        groups = self.memory['queue'].map { |payload| present(payload) }
        log "Sending digest mail to #{user.email} with events [#{ids}]"
        SystemMailer.delay.send_message(:to => user.email, :subject => options['subject'], :headline => options['headline'], :groups => groups)
        self.memory['queue'] = []
        self.memory['events'] = []
      end
    end
  end
end
