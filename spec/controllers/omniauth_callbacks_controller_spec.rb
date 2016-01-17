require 'rails_helper'

describe OmniauthCallbacksController do
  before do
    sign_in users(:bob)
    OmniAuth.config.test_mode = true
    request.env["devise.mapping"] = Devise.mappings[:user]
    request.env["omniauth.auth"] = JSON.parse(File.read(Rails.root.join('spec/data_fixtures/services/twitter.json')))
  end

  describe "accepting a callback url" do
    it "should update the user's credentials" do
      expect {
        get :twitter
      }.to change { users(:bob).services.count }.by(1)
    end

    # it "should work with an unknown provider (for now)" do
    #   request.env["omniauth.auth"]['provider'] = 'unknown'
    #   expect {
    #     get :unknown
    #   }.to change { users(:bob).services.count }.by(1)
    #   expect(users(:bob).services.first.provider).to eq('unknown')
    # end
  end
end
