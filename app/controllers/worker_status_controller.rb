class WorkerStatusController < ApplicationController
  skip_before_filter :authenticate_user!

  def show
    start = Time.now.to_f
    render :json => {
        :pending => Delayed::Job.where("run_at <= ? AND locked_at IS NULL AND attempts = 0", Time.now).count,
        :awaiting_retry => Delayed::Job.where("failed_at IS NULL AND attempts > 0").count,
        :recent_failures => Delayed::Job.where("failed_at IS NOT NULL AND failed_at > ?", 5.days.ago).count,
        :compute_time => Time.now.to_f - start
    }
  end
end
