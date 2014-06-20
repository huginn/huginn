require 'spec_helper'

describe ScenarioImportsController do
  before do
    sign_in users(:bob)
  end

  describe "GET new" do
    it "initializes a new ScenarioImport and renders new" do
      get :new
      assigns(:scenario_import).should be_a(ScenarioImport)
      response.should render_template(:new)
    end
  end

  describe "POST create" do
    it "initializes a ScenarioImport for current_user, passing in params" do
      post :create, :scenario_import => { :url => "bad url" }
      assigns(:scenario_import).user.should == users(:bob)
      assigns(:scenario_import).url.should == "bad url"
      assigns(:scenario_import).should_not be_valid
      response.should render_template(:new)
    end
  end
end

