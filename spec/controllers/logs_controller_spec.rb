require 'spec_helper'

describe LogsController do
  describe "GET index" do
    it "can filter by Agent" do
      sign_in users(:bob)
      get :index, :agent_id => agents(:bob_weather_agent).id
      assigns(:logs).length.should == agents(:bob_weather_agent).logs.length
      assigns(:logs).all? {|i| i.agent.should == agents(:bob_weather_agent) }.should be_true
    end

    it "only loads Agents owned by the current user" do
      sign_in users(:bob)
      lambda {
        get :index, :agent_id => agents(:jane_weather_agent).id
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE clear" do
    it "deletes all logs for a specific Agent" do
      agents(:bob_weather_agent).last_error_log_at = 2.hours.ago
      sign_in users(:bob)
      lambda {
        delete :clear, :agent_id => agents(:bob_weather_agent).id
      }.should change { AgentLog.count }.by(-1 * agents(:bob_weather_agent).logs.count)
      assigns(:logs).length.should == 0
      agents(:bob_weather_agent).reload.logs.count.should == 0
      agents(:bob_weather_agent).last_error_log_at.should be_nil
    end

    it "only deletes logs for an Agent owned by the current user" do
      sign_in users(:bob)
      lambda {
        delete :clear, :agent_id => agents(:jane_weather_agent).id
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
