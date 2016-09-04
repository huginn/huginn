require 'rails_helper'

describe OmniauthCallbacksController do
  before do
    sign_in users(:bob)
    OmniAuth.config.test_mode = true
    request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe "accepting a callback url" do
    it "should update the user's credentials" do
      request.env["omniauth.auth"] = JSON.parse(File.read(Rails.root.join('spec/data_fixtures/services/twitter.json')))
      expect {
        get :twitter
      }.to change { users(:bob).services.count }.by(1)
    end
  end

  describe "handling a provider with non-standard omniauth options" do
    it "should update the user's credentials" do
      request.env["omniauth.auth"] = JSON.parse(File.read(Rails.root.join('spec/data_fixtures/services/37signals.json')))
      expect {
        get "37signals"
      }.to change { users(:bob).services.count }.by(1)
    end
  end
end
