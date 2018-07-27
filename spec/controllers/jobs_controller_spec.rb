require 'rails_helper'

describe JobsController do
  describe "GET index" do
    before do
      async_handler_yaml =
        "--- !ruby/object:ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper\njob_data:\n  job_class: AgentCheckJob\n  job_id: 123id\n  queue_name: default\n  arguments:\n  - %d\n"

      Delayed::Job.create!(handler: async_handler_yaml % [agents(:jane_website_agent).id])
      Delayed::Job.create!(handler: async_handler_yaml % [agents(:bob_website_agent).id])
      Delayed::Job.create!(handler: async_handler_yaml % [agents(:jane_weather_agent).id])
      agents(:jane_website_agent).destroy
      Delayed::Job.create!(handler: async_handler_yaml % [agents(:bob_weather_agent).id], locked_at: Time.now, locked_by: 'test')

      expect(Delayed::Job.count).to be > 0
    end

    it "does not allow normal users" do
      expect(users(:bob)).not_to be_admin
      sign_in users(:bob)
      expect(get(:index)).to redirect_to(root_path)
    end

    it "returns all jobs" do
      expect(users(:jane)).to be_admin
      sign_in users(:jane)
      get :index
      expect(assigns(:jobs).length).to eq(4)
    end
  end

  describe "DELETE destroy" do
    before do
      @not_running = Delayed::Job.create
      @running = Delayed::Job.create(locked_at: Time.now, locked_by: 'test')
      sign_in users(:jane)
    end

    it "destroy a job which is not running" do
      expect { delete :destroy, params: {id: @not_running.id} }.to change(Delayed::Job, :count).by(-1)
    end

    it "does not destroy a running job" do
      expect { delete :destroy, params: {id: @running.id} }.to change(Delayed::Job, :count).by(0)
    end
  end

  describe "PUT run" do
    before do
      @not_running = Delayed::Job.create(run_at: Time.now - 1.hour)
      @running = Delayed::Job.create(locked_at: Time.now, locked_by: 'test')
      @failed = Delayed::Job.create(run_at: Time.now - 1.hour, locked_at: Time.now, failed_at: Time.now)
      sign_in users(:jane)
    end

    it "queue a job which is not running" do
      expect { put :run, params: {id: @not_running.id} }.to change { @not_running.reload.run_at }
    end

    it "queue a job that failed" do
      expect { put :run, params: {id: @failed.id} }.to change { @failed.reload.run_at }
    end

    it "not queue a running job" do
      expect { put :run, params: {id: @running.id} }.not_to change { @not_running.reload.run_at }
    end
  end

  describe "DELETE destroy_failed" do
    before do
      @failed = Delayed::Job.create(failed_at: Time.now - 1.minute)
      @running = Delayed::Job.create(locked_at: Time.now, locked_by: 'test')
      @pending = Delayed::Job.create
      sign_in users(:jane)
    end

    it "just destroy failed jobs" do
      expect { delete :destroy_failed }.to change(Delayed::Job, :count).by(-1)
    end
  end

  describe "DELETE destroy_all" do
    before do
      @failed = Delayed::Job.create(failed_at: Time.now - 1.minute)
      @running = Delayed::Job.create(locked_at: Time.now, locked_by: 'test')
      @pending = Delayed::Job.create
      sign_in users(:jane)
    end

    it "destroys all jobs" do
      expect { delete :destroy_all }.to change(Delayed::Job, :count).by(-2)
      expect(Delayed::Job.find(@running.id)).to be
    end
  end

  describe "POST retry_queued" do
    before do
      @not_running = Delayed::Job.create(run_at: Time.zone.now - 1.hour)
      @not_running.update_attribute(:attempts, 1)
      sign_in users(:jane)
    end

    it "run the queued job" do
      expect(Delayed::Job.last.run_at.to_i).not_to be_within(2).of(Time.zone.now.to_i)
      post :retry_queued
      expect(Delayed::Job.last.run_at.to_i).to be_within(2).of(Time.zone.now.to_i)
    end
  end
end
