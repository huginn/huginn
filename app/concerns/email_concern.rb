module EmailConcern
  extend ActiveSupport::Concern

  MAIN_KEYS = %w[title message text main value]

  included do
    self.validate :validate_email_options
  end

  def validate_email_options
    errors.add(:base, "subject and expected_receive_period_in_days are required") unless options['subject'].present? && options['expected_receive_period_in_days'].present?

    if options['recipients'].present?
      emails = options['recipients']
      emails = [emails] if emails.is_a?(String)
      unless emails.all? { |email| email =~ Devise.email_regexp || email =~ /\{/ }
        errors.add(:base, "'when provided, 'recipients' should be an email address or an array of email addresses")
      end
    end
  end

  def recipients(payload = {})
    emails = interpolated(payload)['recipients']
    if emails.present?
      if emails.is_a?(String)
        [emails]
      else
        emails
      end
    else
      [user.email]
    end
  end

  def working?
    last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
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
