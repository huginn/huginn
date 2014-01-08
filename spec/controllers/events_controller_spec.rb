require 'spec_helper'

describe EventsController do
  before do
    Event.where(:user_id => users(:bob).id).count.should > 0
    Event.where(:user_id => users(:jane).id).count.should > 0
  end

  describe "GET index" do
    it "only returns Events created by Agents of the current user" do
      sign_in users(:bob)
      get :index
      assigns(:events).all? {|i| i.user.should == users(:bob) }.should be_true
    end

    it "can filter by Agent" do
      sign_in users(:bob)
      get :index, :agent => agents(:bob_website_agent)
      assigns(:events).length.should == agents(:bob_website_agent).events.length
      assigns(:events).all? {|i| i.agent.should == agents(:bob_website_agent) }.should be_true

      lambda {
        get :index, :agent => agents(:jane_website_agent)
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET show" do
    it "only shows Events for the current user" do
      sign_in users(:bob)
      get :show, :id => events(:bob_website_agent_event).to_param
      assigns(:event).should eq(events(:bob_website_agent_event))

      lambda {
        get :show, :id => events(:jane_website_agent_event).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST reemit" do
    before do
      request.env["HTTP_REFERER"] = "/events"
      sign_in users(:bob)
    end

    it "clones and re-emits events" do
      lambda {
        post :reemit, :id => events(:bob_website_agent_event).to_param
      }.should change { Event.count }.by(1)
      Event.last.payload.should == events(:bob_website_agent_event).payload
      Event.last.agent.should == events(:bob_website_agent_event).agent
      Event.last.created_at.to_i.should be_within(2).of(Time.now.to_i)
    end

    it "can only re-emit Events for the current user" do
      lambda {
        post :reemit, :id => events(:jane_website_agent_event).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE destroy" do
    it "only deletes events for the current user" do
      sign_in users(:bob)
      lambda {
        delete :destroy, :id => events(:bob_website_agent_event).to_param
      }.should change { Event.count }.by(-1)

      lambda {
        delete :destroy, :id => events(:jane_website_agent_event).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
