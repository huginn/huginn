class WorkerStatusController < ApplicationController
  def show
    start = Time.now
    events = current_user.events

    if params[:since_id].present?
      since_id = params[:since_id].to_i
      events = events.where('id > ?', since_id)
    end

    result = events.select('COUNT(id) AS count', 'MIN(id) AS min_id', 'MAX(id) AS max_id').reorder('min(created_at)').first
    count, min_id, max_id = result.count, result.min_id, result.max_id

    case max_id
    when nil
    when min_id
      events_url = events_path(hl: max_id)
    else
      events_url = events_path(hl: "#{min_id}-#{max_id}")
    end

    render json: {
      pending: WorkerStatus.pending(start),
      awaiting_retry: WorkerStatus.awaiting_retry,
      recent_failures: WorkerStatus.recent_failures,
      event_count: count,
      max_id: max_id || 0,
      events_url: events_url,
      compute_time: Time.now - start
    }
  end
end
