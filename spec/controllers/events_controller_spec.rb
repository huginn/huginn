require 'spec_helper'

describe EventsController do
  before do
    Event.where(:user_id => users(:bob).id).count.should > 0
    Event.where(:user_id => users(:jane).id).count.should > 0
  end

  describe "GET index" do
    it "only returns Agents for the current user" do
      sign_in users(:bob)
      get :index
      assigns(:events).all? {|i| i.user.should == users(:bob) }.should be_true
    end
  end

  describe "GET show" do
    it "only shows Agents for the current user" do
      sign_in users(:bob)
      get :show, :id => events(:bob_website_agent_event).to_param
      assigns(:event).should eq(events(:bob_website_agent_event))

      lambda {
        get :show, :id => events(:jane_website_agent_event).to_param
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
