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
      assigns(:agents).all? {|i| i.user.should == users(:bob) }.should be_truthy
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

  describe "POST run" do
    it "triggers Agent.async_check with the Agent's ID" do
      sign_in users(:bob)
      mock(Agent).async_check(agents(:bob_manual_event_agent).id)
      post :run, :id => agents(:bob_manual_event_agent).to_param
    end

    it "can only be accessed by the Agent's owner" do
      sign_in users(:jane)
      lambda {
        post :run, :id => agents(:bob_manual_event_agent).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST remove_events" do
    it "deletes all events created by the given Agent" do
      sign_in users(:bob)
      agent_event = events(:bob_website_agent_event).id
      other_event = events(:jane_website_agent_event).id
      post :remove_events, :id => agents(:bob_website_agent).to_param
      Event.where(:id => agent_event).count.should == 0
      Event.where(:id => other_event).count.should == 1
    end

    it "can only be accessed by the Agent's owner" do
      sign_in users(:jane)
      lambda {
        post :remove_events, :id => agents(:bob_website_agent).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST propagate" do
    it "runs event propagation for all Agents" do
      sign_in users(:bob)
      mock.proxy(Agent).receive!
      post :propagate
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

  describe "GET new with :id" do
    it "opens a clone of a given Agent" do
      sign_in users(:bob)
      get :new, :id => agents(:bob_website_agent).to_param
      assigns(:agent).attributes.should eq(users(:bob).agents.build_clone(agents(:bob_website_agent)).attributes)
    end

    it "only allows the current user to clone his own Agent" do
      sign_in users(:bob)

      lambda {
        get :new, :id => agents(:jane_website_agent).to_param
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

    it "accepts JSON requests" do
      sign_in users(:bob)
      post :update, :id => agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name"), :format => :json
      agents(:bob_website_agent).reload.name.should == "New name"
      JSON.parse(response.body)['name'].should == "New name"
      response.should be_success
    end

    it "will not accept Agent sources owned by other users" do
      sign_in users(:bob)
      post :update, :id => agents(:bob_website_agent).to_param, :agent => valid_attributes(:source_ids => [agents(:jane_weather_agent).id])
      assigns(:agent).should have(1).errors_on(:sources)
    end

    it "will not accept Scenarios owned by other users" do
      sign_in users(:bob)
      post :update, :id => agents(:bob_website_agent).to_param, :agent => valid_attributes(:scenario_ids => [scenarios(:jane_weather).id])
      assigns(:agent).should have(1).errors_on(:scenarios)
    end

    it "shows errors" do
      sign_in users(:bob)
      post :update, :id => agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "")
      assigns(:agent).should have(1).errors_on(:name)
      response.should render_template("edit")
    end

    describe "redirecting back" do
      before do
        sign_in users(:bob)
      end

      it "can redirect back to the show path" do
        post :update, :id => agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name"), :return => "show"
        response.should redirect_to(agent_path(agents(:bob_website_agent)))
      end

      it "redirect back to the index path by default" do
        post :update, :id => agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name")
        response.should redirect_to(agents_path)
      end

      it "accepts return paths to scenarios" do
        post :update, :id => agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name"), :return => "/scenarios/2"
        response.should redirect_to("/scenarios/2")
      end

      it "sanitizes return paths" do
        post :update, :id => agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name"), :return => "/scenar"
        response.should redirect_to(agents_path)

        post :update, :id => agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name"), :return => "http://google.com"
        response.should redirect_to(agents_path)

        post :update, :id => agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name"), :return => "javascript:alert(1)"
        response.should redirect_to(agents_path)
      end
    end
  end

  describe "PUT leave_scenario" do
    it "removes an Agent from the given Scenario for the current user" do
      sign_in users(:bob)

      agents(:bob_weather_agent).scenarios.should include(scenarios(:bob_weather))
      put :leave_scenario, :id => agents(:bob_weather_agent).to_param, :scenario_id => scenarios(:bob_weather).to_param
      agents(:bob_weather_agent).scenarios.should_not include(scenarios(:bob_weather))

      Scenario.where(:id => scenarios(:bob_weather).id).should exist

      lambda {
        put :leave_scenario, :id => agents(:jane_weather_agent).to_param, :scenario_id => scenarios(:jane_weather).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
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
