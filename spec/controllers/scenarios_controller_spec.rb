require 'rails_helper'

describe ScenariosController do
  def valid_attributes(options = {})
    { :name => "some_name" }.merge(options)
  end

  before do
    sign_in users(:bob)
  end

  describe "GET index" do
    it "only returns Scenarios for the current user" do
      get :index
      expect(assigns(:scenarios).all? {|i| expect(i.user).to eq(users(:bob)) }).to be_truthy
    end
  end

  describe "GET show" do
    it "only shows Scenarios for the current user" do
      get :show, params: {:id => scenarios(:bob_weather).to_param}
      expect(assigns(:scenario)).to eq(scenarios(:bob_weather))

      expect {
        get :show, params: {:id => scenarios(:jane_weather).to_param}
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "loads Agents for the requested Scenario" do
      get :show, params: {:id => scenarios(:bob_weather).to_param}
      expect(assigns(:agents).pluck(:id).sort).to eq(scenarios(:bob_weather).agents.pluck(:id).sort)
    end
  end

  describe "GET share" do
    it "only displays Scenario share information for the current user" do
      get :share, params: {:id => scenarios(:bob_weather).to_param}
      expect(assigns(:scenario)).to eq(scenarios(:bob_weather))

      expect {
        get :share, params: {:id => scenarios(:jane_weather).to_param}
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET export" do
    it "returns a JSON file download from an instantiated AgentsExporter" do
      get :export, params: {:id => scenarios(:bob_weather).to_param}
      expect(assigns(:exporter).options[:name]).to eq(scenarios(:bob_weather).name)
      expect(assigns(:exporter).options[:description]).to eq(scenarios(:bob_weather).description)
      expect(assigns(:exporter).options[:agents]).to eq(scenarios(:bob_weather).agents)
      expect(assigns(:exporter).options[:guid]).to eq(scenarios(:bob_weather).guid)
      expect(assigns(:exporter).options[:tag_fg_color]).to eq(scenarios(:bob_weather).tag_fg_color)
      expect(assigns(:exporter).options[:tag_bg_color]).to eq(scenarios(:bob_weather).tag_bg_color)
      expect(assigns(:exporter).options[:source_url]).to be_falsey
      expect(response.headers['Content-Disposition']).to eq('attachment; filename="bob-s-weather-alert-scenario.json"')
      expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
      expect(JSON.parse(response.body)["name"]).to eq(scenarios(:bob_weather).name)
    end

    it "only exports private Scenarios for the current user" do
      get :export, params: {:id => scenarios(:bob_weather).to_param}
      expect(assigns(:scenario)).to eq(scenarios(:bob_weather))

      expect {
        get :export, params: {:id => scenarios(:jane_weather).to_param}
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    describe "public exports" do
      before do
        scenarios(:jane_weather).update_attribute :public, true
      end

      it "exports public scenarios for other users when logged in" do
        get :export, params: {:id => scenarios(:jane_weather).to_param}
        expect(assigns(:scenario)).to eq(scenarios(:jane_weather))
        expect(assigns(:exporter).options[:source_url]).to eq(export_scenario_url(scenarios(:jane_weather)))
      end

      it "exports public scenarios for other users when logged out" do
        sign_out :user
        get :export, params: {:id => scenarios(:jane_weather).to_param}
        expect(assigns(:scenario)).to eq(scenarios(:jane_weather))
        expect(assigns(:exporter).options[:source_url]).to eq(export_scenario_url(scenarios(:jane_weather)))
      end
    end
  end

  describe "GET edit" do
    it "only shows Scenarios for the current user" do
      get :edit, params: {:id => scenarios(:bob_weather).to_param}
      expect(assigns(:scenario)).to eq(scenarios(:bob_weather))

      expect {
        get :edit, params: {:id => scenarios(:jane_weather).to_param}
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST create" do
    it "creates Scenarios for the current user" do
      expect {
        post :create, params: {:scenario => valid_attributes}
      }.to change { users(:bob).scenarios.count }.by(1)
    end

    it "shows errors" do
      expect {
        post :create, params: {:scenario => valid_attributes(:name => "")}
      }.not_to change { users(:bob).scenarios.count }
      expect(assigns(:scenario)).to have(1).errors_on(:name)
      expect(response).to render_template("new")
    end

    it "will not create Scenarios for other users" do
      expect {
        post :create, params: {:scenario => valid_attributes(:user_id => users(:jane).id)}
      }.to raise_error(ActionController::UnpermittedParameters)
    end
  end

  describe "PUT update" do
    it "updates attributes on Scenarios for the current user" do
      post :update, params: {:id => scenarios(:bob_weather).to_param, :scenario => { :name => "new_name", :public => "1" }}
      expect(response).to redirect_to(scenario_path(scenarios(:bob_weather)))
      expect(scenarios(:bob_weather).reload.name).to eq("new_name")
      expect(scenarios(:bob_weather)).to be_public

      expect {
        post :update, params: {:id => scenarios(:jane_weather).to_param, :scenario => { :name => "new_name" }}
      }.to raise_error(ActiveRecord::RecordNotFound)
      expect(scenarios(:jane_weather).reload.name).not_to eq("new_name")
    end

    it "shows errors" do
      post :update, params: {:id => scenarios(:bob_weather).to_param, :scenario => { :name => "" }}
      expect(assigns(:scenario)).to have(1).errors_on(:name)
      expect(response).to render_template("edit")
    end

    it 'adds an agent to the scenario' do
      expect {
        post :update, params: {:id => scenarios(:bob_weather).to_param, :scenario => { :name => "new_name", :public => "1", agent_ids: scenarios(:bob_weather).agent_ids + [agents(:bob_website_agent).id] }}
      }.to change { scenarios(:bob_weather).reload.agent_ids.length }.by(1)
    end
  end

  describe 'PUT enable_or_disable_all_agents' do
    it 'updates disabled on all agents in a scenario for the current user' do
      @params = {"scenario"=>{"disabled"=>"true"}, "commit"=>"Yes", "id"=> scenarios(:bob_weather).id}
      put :enable_or_disable_all_agents, params: @params
      expect(agents(:bob_rain_notifier_agent).disabled).to eq(true)
      expect(response).to redirect_to(scenario_path(scenarios(:bob_weather)))
    end
  end

  describe "DELETE destroy" do
    it "destroys only Scenarios owned by the current user" do
      expect {
        delete :destroy, params: {:id => scenarios(:bob_weather).to_param}
      }.to change(Scenario, :count).by(-1)

      expect {
        delete :destroy, params: {:id => scenarios(:jane_weather).to_param}
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "passes the mode to the model" do
      expect {
        delete :destroy, params: {id: scenarios(:bob_weather).to_param, mode: 'all_agents'}
      }.to change(Agent, :count).by(-2)
    end
  end
end
