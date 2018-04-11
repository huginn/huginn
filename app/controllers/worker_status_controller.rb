class WorkerStatusController < ApplicationController
  def show
    start = Time.now
    events = current_user.events

    if params[:since_id].present?
      since_id = params[:since_id].to_i
      events = events.where('id > ?', since_id)
    end

    result = events.select('COUNT(id) AS count', 'MIN(id) AS min_id', 'MAX(id) AS max_id').reorder(Arel.sql('min(created_at)')).first
    count, min_id, max_id = result.count, result.min_id, result.max_id

    case max_id
    when nil
    when min_id
      events_url = events_path(hl: max_id)
    else
      events_url = events_path(hl: "#{min_id}-#{max_id}")
    end

    render json: {
      pending: Delayed::Job.pending.where("run_at <= ?", start).count,
      awaiting_retry: Delayed::Job.awaiting_retry.count,
      recent_failures: Delayed::Job.failed_jobs.where('failed_at > ?', 5.days.ago).count,
      event_count: count,
      max_id: max_id || 0,
      events_url: events_url,
      compute_time: Time.now - start
    }
  end
end
