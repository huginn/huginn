require 'spec_helper'

describe AgentsController do
  def valid_attributes(options = {})
    {
        :type => "Agents::WebsiteAgent",
        :name => "Something",
        :options => agents(:bob_website_agent).options,
        :source_ids => [agents(:bob_weather_agent).id, ""]
    }.merge(options)
  end

  describe "GET index" do
    it "only returns Agents for the current user" do
      sign_in users(:bob)
      get :index
      assigns(:agents).all? {|i| i.user.should == users(:bob) }.should be_true
    end
  end

  describe "POST handle_details_post" do
    it "passes control to handle_details_post on the agent" do
      sign_in users(:bob)
      post :handle_details_post, :id => agents(:bob_manual_event_agent).to_param, :payload => { :foo => "bar" }
      JSON.parse(response.body).should == { "success" => true }
      agents(:bob_manual_event_agent).events.last.payload.should == { 'foo' => "bar" }
    end

    it "can only be accessed by the Agent's owner" do
      sign_in users(:jane)
      lambda {
        post :handle_details_post, :id => agents(:bob_manual_event_agent).to_param, :payload => { :foo => :bar }
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET show" do
    it "only shows Agents for the current user" do
      sign_in users(:bob)
      get :show, :id => agents(:bob_website_agent).to_param
      assigns(:agent).should eq(agents(:bob_website_agent))

      lambda {
        get :show, :id => agents(:jane_website_agent).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET edit" do
    it "only shows Agents for the current user" do
      sign_in users(:bob)
      get :edit, :id => agents(:bob_website_agent).to_param
      assigns(:agent).should eq(agents(:bob_website_agent))

      lambda {
        get :edit, :id => agents(:jane_website_agent).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST create" do
    it "errors on bad types" do
      sign_in users(:bob)
      expect {
        post :create, :agent => valid_attributes(:type => "Agents::ThisIsFake")
      }.not_to change { users(:bob).agents.count }
      assigns(:agent).should be_a(Agent)
      assigns(:agent).should have(1).error_on(:type)

      sign_in users(:bob)
      expect {
        post :create, :agent => valid_attributes(:type => "Object")
      }.not_to change { users(:bob).agents.count }
      assigns(:agent).should be_a(Agent)
      assigns(:agent).should have(1).error_on(:type)
      sign_in users(:bob)

      expect {
        post :create, :agent => valid_attributes(:type => "Agent")
      }.not_to change { users(:bob).agents.count }
      assigns(:agent).should be_a(Agent)
      assigns(:agent).should have(1).error_on(:type)

      expect {
        post :create, :agent => valid_attributes(:type => "User")
      }.not_to change { users(:bob).agents.count }
      assigns(:agent).should be_a(Agent)
      assigns(:agent).should have(1).error_on(:type)
    end

    it "creates Agents for the current user" do
      sign_in users(:bob)
      expect {
        expect {
          post :create, :agent => valid_attributes
        }.to change { users(:bob).agents.count }.by(1)
      }.to change { Link.count }.by(1)
      assigns(:agent).should be_a(Agents::WebsiteAgent)
    end

    it "shows errors" do
      sign_in users(:bob)
      expect {
        post :create, :agent => valid_attributes(:name => "")
      }.not_to change { users(:bob).agents.count }
      assigns(:agent).should have(1).errors_on(:name)
      response.should render_template("new")
    end

    it "will not accept Agent sources owned by other users" do
      sign_in users(:bob)
      expect {
        expect {
          post :create, :agent => valid_attributes(:source_ids => [agents(:jane_weather_agent).id])
        }.not_to change { users(:bob).agents.count }
      }.not_to change { Link.count }
    end
  end

  describe "PUT update" do
    it "does not allow changing types" do
      sign_in users(:bob)
      post :update, :id => agents(:bob_website_agent).to_param, :agent => valid_attributes(:type => "Agents::WeatherAgent")
      assigns(:agent).should have(1).errors_on(:type)
      response.should render_template("edit")
    end

    it "updates attributes on Agents for the current user" do
      sign_in users(:bob)
      post :update, :id => agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name")
      response.should redirect_to(agents_path)
      agents(:bob_website_agent).reload.name.should == "New name"

      lambda {
        post :update, :id => agents(:jane_website_agent).to_param, :agent => valid_attributes(:name => "New name")
      }.should raise_error(ActiveRecord::RecordNotFound)
    end

    it "will not accept Agent sources owned by other users" do
      sign_in users(:bob)
      post :update, :id => agents(:bob_website_agent).to_param, :agent => valid_attributes(:source_ids => [agents(:jane_weather_agent).id])
      assigns(:agent).should have(1).errors_on(:sources)
    end

    it "shows errors" do
      sign_in users(:bob)
      post :update, :id => agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "")
      assigns(:agent).should have(1).errors_on(:name)
      response.should render_template("edit")
    end
  end

  describe "DELETE destroy" do
    it "destroys only Agents owned by the current user" do
      sign_in users(:bob)
      expect {
        delete :destroy, :id => agents(:bob_website_agent).to_param
      }.to change(Agent, :count).by(-1)

      lambda {
        delete :destroy, :id => agents(:jane_website_agent).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
