require 'spec_helper'

describe JobsController do

  describe "GET index" do
    before do
      Delayed::Job.create!
      Delayed::Job.create!
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
      expect(assigns(:jobs).length).to eq(2)
    end
  end

  describe "DELETE destroy" do
    before do
      @not_running = Delayed::Job.create
      @running = Delayed::Job.create(locked_at: Time.now, locked_by: 'test')
      sign_in users(:jane)
    end

    it "destroy a job which is not running" do
      expect { delete :destroy, id: @not_running.id }.to change(Delayed::Job, :count).by(-1)
    end

    it "does not destroy a running job" do
      expect { delete :destroy, id: @running.id }.to change(Delayed::Job, :count).by(0)
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
      expect { put :run, id: @not_running.id }.to change { @not_running.reload.run_at }
    end

    it "queue a job that failed" do
      expect { put :run, id: @failed.id }.to change { @failed.reload.run_at }
    end

    it "not queue a running job" do
      expect { put :run, id: @running.id }.not_to change { @not_running.reload.run_at }
    end
  end

  describe "DELETE destroy_failed" do
    before do
      @failed = Delayed::Job.create(failed_at: Time.now - 1.minute)
      @running = Delayed::Job.create(locked_at: Time.now, locked_by: 'test')
      sign_in users(:jane)
    end

    it "just destroy failed jobs" do
      expect { delete :destroy_failed, id: @failed.id }.to change(Delayed::Job, :count).by(-1)
      expect { delete :destroy_failed, id: @running.id }.to change(Delayed::Job, :count).by(0)
    end
  end
end
