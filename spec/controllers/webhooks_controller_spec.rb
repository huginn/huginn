require 'spec_helper'

describe WebhooksController do
  class Agents::WebhookReceiverAgent < Agent
    cannot_receive_events!
    cannot_be_scheduled!

    def receive_webhook(params)
      if params.delete(:secret) == options[:secret]
        memory[:webhook_values] = params
        ["success", 200]
      else
        ["failure", 404]
      end
    end
  end

  before do
    stub(Agents::WebhookReceiverAgent).valid_type?("Agents::WebhookReceiverAgent") { true }
    @agent = Agents::WebhookReceiverAgent.new(:name => "something", :options => { :secret => "my_secret" })
    @agent.user = users(:bob)
    @agent.save!
  end

  it "should not require login to trigger a webhook" do
    @agent.last_webhook_at.should be_nil
    post :create, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"
    @agent.reload.last_webhook_at.should be_within(2).of(Time.now)
    response.body.should == "success"
    response.should be_success
  end

  it "should call receive_webhook" do
    post :create, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"
    @agent.reload.memory[:webhook_values].should == { 'key' => "value", 'another_key' => "5" }
    response.body.should == "success"
    response.should be_success

    post :create, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "not_my_secret", :no => "go"
    @agent.reload.memory[:webhook_values].should_not == { 'no' => "go" }
    response.body.should == "failure"
    response.should be_missing
  end

  it "should fail on incorrect users" do
    post :create, :user_id => users(:jane).to_param, :agent_id => @agent.id, :secret => "my_secret", :no => "go"
    response.should be_missing
  end

  it "should fail on incorrect agents" do
    post :create, :user_id => users(:bob).to_param, :agent_id => 454545, :secret => "my_secret", :no => "go"
    response.should be_missing
  end
end