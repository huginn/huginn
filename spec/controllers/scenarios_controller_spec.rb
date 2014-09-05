require 'spec_helper'

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
      assigns(:scenarios).all? {|i| i.user.should == users(:bob) }.should be_truthy
    end
  end

  describe "GET show" do
    it "only shows Scenarios for the current user" do
      get :show, :id => scenarios(:bob_weather).to_param
      assigns(:scenario).should eq(scenarios(:bob_weather))

      lambda {
        get :show, :id => scenarios(:jane_weather).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end

    it "loads Agents for the requested Scenario" do
      get :show, :id => scenarios(:bob_weather).to_param
      assigns(:agents).pluck(:id).should eq(scenarios(:bob_weather).agents.pluck(:id))
    end
  end

  describe "GET share" do
    it "only displays Scenario share information for the current user" do
      get :share, :id => scenarios(:bob_weather).to_param
      assigns(:scenario).should eq(scenarios(:bob_weather))

      lambda {
        get :share, :id => scenarios(:jane_weather).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET export" do
    it "returns a JSON file download from an instantiated AgentsExporter" do
      get :export, :id => scenarios(:bob_weather).to_param
      assigns(:exporter).options[:name].should == scenarios(:bob_weather).name
      assigns(:exporter).options[:description].should == scenarios(:bob_weather).description
      assigns(:exporter).options[:agents].should == scenarios(:bob_weather).agents
      assigns(:exporter).options[:guid].should == scenarios(:bob_weather).guid
      assigns(:exporter).options[:tag_fg_color].should == scenarios(:bob_weather).tag_fg_color
      assigns(:exporter).options[:tag_bg_color].should == scenarios(:bob_weather).tag_bg_color
      assigns(:exporter).options[:source_url].should be_falsey
      response.headers['Content-Disposition'].should == 'attachment; filename="bob-s-weather-alert-scenario.json"'
      response.headers['Content-Type'].should == 'application/json; charset=utf-8'
      JSON.parse(response.body)["name"].should == scenarios(:bob_weather).name
    end

    it "only exports private Scenarios for the current user" do
      get :export, :id => scenarios(:bob_weather).to_param
      assigns(:scenario).should eq(scenarios(:bob_weather))

      lambda {
        get :export, :id => scenarios(:jane_weather).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end

    describe "public exports" do
      before do
        scenarios(:jane_weather).update_attribute :public, true
      end

      it "exports public scenarios for other users when logged in" do
        get :export, :id => scenarios(:jane_weather).to_param
        assigns(:scenario).should eq(scenarios(:jane_weather))
        assigns(:exporter).options[:source_url].should == export_scenario_url(scenarios(:jane_weather))
      end

      it "exports public scenarios for other users when logged out" do
        sign_out :user
        get :export, :id => scenarios(:jane_weather).to_param
        assigns(:scenario).should eq(scenarios(:jane_weather))
        assigns(:exporter).options[:source_url].should == export_scenario_url(scenarios(:jane_weather))
      end
    end
  end

  describe "GET edit" do
    it "only shows Scenarios for the current user" do
      get :edit, :id => scenarios(:bob_weather).to_param
      assigns(:scenario).should eq(scenarios(:bob_weather))

      lambda {
        get :edit, :id => scenarios(:jane_weather).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST create" do
    it "creates Scenarios for the current user" do
      expect {
        post :create, :scenario => valid_attributes
      }.to change { users(:bob).scenarios.count }.by(1)
    end

    it "shows errors" do
      expect {
        post :create, :scenario => valid_attributes(:name => "")
      }.not_to change { users(:bob).scenarios.count }
      assigns(:scenario).should have(1).errors_on(:name)
      response.should render_template("new")
    end

    it "will not create Scenarios for other users" do
      expect {
        post :create, :scenario => valid_attributes(:user_id => users(:jane).id)
      }.to raise_error(ActiveModel::MassAssignmentSecurity::Error)
    end
  end

  describe "PUT update" do
    it "updates attributes on Scenarios for the current user" do
      post :update, :id => scenarios(:bob_weather).to_param, :scenario => { :name => "new_name", :public => "1" }
      response.should redirect_to(scenario_path(scenarios(:bob_weather)))
      scenarios(:bob_weather).reload.name.should == "new_name"
      scenarios(:bob_weather).should be_public

      lambda {
        post :update, :id => scenarios(:jane_weather).to_param, :scenario => { :name => "new_name" }
      }.should raise_error(ActiveRecord::RecordNotFound)
      scenarios(:jane_weather).reload.name.should_not == "new_name"
    end

    it "shows errors" do
      post :update, :id => scenarios(:bob_weather).to_param, :scenario => { :name => "" }
      assigns(:scenario).should have(1).errors_on(:name)
      response.should render_template("edit")
    end
  end

  describe "DELETE destroy" do
    it "destroys only Scenarios owned by the current user" do
      expect {
        delete :destroy, :id => scenarios(:bob_weather).to_param
      }.to change(Scenario, :count).by(-1)

      lambda {
        delete :destroy, :id => scenarios(:jane_weather).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
