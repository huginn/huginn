require 'rails_helper'

describe EventsController do
  before do
    expect(Event.where(:user_id => users(:bob).id).count).to be > 0
    expect(Event.where(:user_id => users(:jane).id).count).to be > 0
  end

  describe "GET index" do
    it "only returns Events created by Agents of the current user" do
      sign_in users(:bob)
      get :index
      expect(assigns(:events).all? {|i| expect(i.user).to eq(users(:bob)) }).to be_truthy
    end

    it "can filter by Agent" do
      sign_in users(:bob)
      get :index, :agent_id => agents(:bob_website_agent)
      expect(assigns(:events).length).to eq(agents(:bob_website_agent).events.length)
      expect(assigns(:events).all? {|i| expect(i.agent).to eq(agents(:bob_website_agent)) }).to be_truthy

      expect {
        get :index, :agent_id => agents(:jane_website_agent)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET show" do
    it "only shows Events for the current user" do
      sign_in users(:bob)
      get :show, :id => events(:bob_website_agent_event).to_param
      expect(assigns(:event)).to eq(events(:bob_website_agent_event))

      expect {
        get :show, :id => events(:jane_website_agent_event).to_param
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST reemit" do
    before do
      request.env["HTTP_REFERER"] = "/events"
      sign_in users(:bob)
    end

    it "clones and re-emits events" do
      expect {
        post :reemit, :id => events(:bob_website_agent_event).to_param
      }.to change { Event.count }.by(1)
      expect(Event.last.payload).to eq(events(:bob_website_agent_event).payload)
      expect(Event.last.agent).to eq(events(:bob_website_agent_event).agent)
      expect(Event.last.created_at.to_i).to be_within(2).of(Time.now.to_i)
    end

    it "can only re-emit Events for the current user" do
      expect {
        post :reemit, :id => events(:jane_website_agent_event).to_param
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE destroy" do
    it "only deletes events for the current user" do
      sign_in users(:bob)
      expect {
        delete :destroy, :id => events(:bob_website_agent_event).to_param
      }.to change { Event.count }.by(-1)

      expect {
        delete :destroy, :id => events(:jane_website_agent_event).to_param
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
