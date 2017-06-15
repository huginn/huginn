module WorkingHelpers
  extend ActiveSupport::Concern

  def event_created_within?(days)
    last_event_at && last_event_at > days.to_i.days.ago
  end

  def recent_error_logs?
    last_event_at && last_error_log_at && last_error_log_at > (last_event_at - 2.minutes)
  end

  def received_event_without_error?
    (last_receive_at.present? && last_error_log_at.blank?) || (last_receive_at.present? && last_error_log_at.present? && last_receive_at > last_error_log_at)
  end

  def checked_without_error?
    (last_check_at.present? && last_error_log_at.nil?) || (last_check_at.present? && last_error_log_at.present? && last_check_at > last_error_log_at)
  end
end
