require 'rails_helper'

describe ScenarioImportsController do
  before do
    sign_in users(:bob)
  end

  describe "GET new" do
    it "initializes a new ScenarioImport and renders new" do
      get :new
      expect(assigns(:scenario_import)).to be_a(ScenarioImport)
      expect(response).to render_template(:new)
    end
  end

  describe "POST create" do
    it "initializes a ScenarioImport for current_user, passing in params" do
      post :create, params: {:scenario_import => { :url => "bad url" }}
      expect(assigns(:scenario_import).user).to eq(users(:bob))
      expect(assigns(:scenario_import).url).to eq("bad url")
      expect(assigns(:scenario_import)).not_to be_valid
      expect(response).to render_template(:new)
    end
  end
end

