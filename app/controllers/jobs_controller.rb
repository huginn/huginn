class JobsController < ApplicationController
  before_action :authenticate_admin!

  def index
    @jobs = Delayed::Job.order("coalesce(failed_at,'1000-01-01'), run_at asc").page(params[:page])

    respond_to do |format|
      format.html { render layout: !request.xhr? }
      format.json { render json: @jobs }
    end
  end

  def destroy
    @job = Delayed::Job.find(params[:id])

    respond_to do |format|
      if !running? && @job.destroy
        format.html { redirect_to jobs_path, notice: "Job deleted." }
        format.json { head :no_content }
      else
        format.html { redirect_to jobs_path, alert: 'Can not delete a running job.' }
        format.json { render json: @job.errors, status: :unprocessable_entity }
      end
    end
  end

  def run
    @job = Delayed::Job.find(params[:id])
    @job.last_error = nil

    respond_to do |format|
      if !running? && @job.update_attributes!(run_at: Time.now, failed_at: nil)
        format.html { redirect_to jobs_path, notice: "Job enqueued." }
        format.json { render json: @job, status: :ok }
      else
        format.html { redirect_to jobs_path, alert: 'Can not enqueue a running job.' }
        format.json { render json: @job.errors, status: :unprocessable_entity }
      end
    end
  end

  def retry_queued
    @jobs = Delayed::Job.awaiting_retry.update_all(run_at: Time.zone.now)
    
    respond_to do |format|
      format.html { redirect_to jobs_path, notice: "Queued jobs getting retried." }
      format.json { head :no_content }
    end
  end

  def destroy_failed
    Delayed::Job.where.not(failed_at: nil).delete_all

    respond_to do |format|
      format.html { redirect_to jobs_path, notice: "Failed jobs removed." }
      format.json { head :no_content }
    end
  end

  def destroy_all
    Delayed::Job.where(locked_at: nil).delete_all

    respond_to do |format|
      format.html { redirect_to jobs_path, notice: "All jobs removed." }
      format.json { head :no_content }
    end
  end

  private

  def running?
    (@job.locked_at || @job.locked_by) && @job.failed_at.nil?
  end
end
