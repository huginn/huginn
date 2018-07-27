require 'rails_helper'

describe LogsController do
  describe "GET index" do
    it "can filter by Agent" do
      sign_in users(:bob)
      get :index, params: {:agent_id => agents(:bob_weather_agent).id}
      expect(assigns(:logs).length).to eq(agents(:bob_weather_agent).logs.length)
      expect(assigns(:logs).all? {|i| expect(i.agent).to eq(agents(:bob_weather_agent)) }).to be_truthy
    end

    it "only loads Agents owned by the current user" do
      sign_in users(:bob)
      expect {
        get :index, params: {:agent_id => agents(:jane_weather_agent).id}
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE clear" do
    it "deletes all logs for a specific Agent" do
      agents(:bob_weather_agent).last_error_log_at = 2.hours.ago
      sign_in users(:bob)
      expect {
        delete :clear, params: {:agent_id => agents(:bob_weather_agent).id}
      }.to change { AgentLog.count }.by(-1 * agents(:bob_weather_agent).logs.count)
      expect(assigns(:logs).length).to eq(0)
      expect(agents(:bob_weather_agent).reload.logs.count).to eq(0)
      expect(agents(:bob_weather_agent).last_error_log_at).to be_nil
    end

    it "only deletes logs for an Agent owned by the current user" do
      sign_in users(:bob)
      expect {
        delete :clear, params: {:agent_id => agents(:jane_weather_agent).id}
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
