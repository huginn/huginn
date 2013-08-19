module Agents
  class DigestEmailAgent < Agent
    MAIN_KEYS = %w[title message text main value].map(&:to_sym)
    default_schedule "5am"

    description <<-MD
      The DigestEmailAgent collects any Events sent to it and sends them all via email when run.
      The email will be sent to your account's address and will have a `subject` and an optional `headline` before
      listing the Events.  If the Events' payloads contain a `:message`, that will be highlighted, otherwise everything in
      their payloads will be shown.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.
    MD

    def default_options
      {
          :subject => "You have some notifications!",
          :headline => "Your notifications:",
          :expected_receive_period_in_days => "2"
      }
    end

    def working?
      last_receive_at && last_receive_at > options[:expected_receive_period_in_days].to_i.days.ago
    end

    def validate_options
      errors.add(:base, "subject and expected_receive_period_in_days are required") unless options[:subject].present? && options[:expected_receive_period_in_days].present?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        self.memory[:queue] ||= []
        self.memory[:queue] << event.payload
      end
    end

    def check
      if self.memory[:queue] && self.memory[:queue].length > 0
        groups = self.memory[:queue].map { |payload| present(payload) }
        puts "Sending mail to #{user.email}..." unless Rails.env.test?
        SystemMailer.delay.send_message(:to => user.email, :subject => options[:subject], :headline => options[:headline], :groups => groups)
        self.memory[:queue] = []
      end
    end

    def present(payload)
      if payload.is_a?(Hash)
        payload = ActiveSupport::HashWithIndifferentAccess.new(payload)
        MAIN_KEYS.each do |key|
          return { :title => payload[key].to_s, :entries => present_hash(payload, key) } if payload.has_key?(key)
        end

        { :title => "Event", :entries => present_hash(payload) }
      else
        { :title => payload.to_s, :entries => [] }
      end
    end

    def present_hash(hash, skip_key = nil)
      hash.to_a.sort_by {|a| a.first.to_s }.map { |k, v| "#{k}: #{v}" unless k.to_s == skip_key.to_s }.compact
    end
  end
end