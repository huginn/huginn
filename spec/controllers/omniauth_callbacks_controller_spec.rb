require 'rails_helper'

describe OmniauthCallbacksController do
  before do
    sign_in users(:bob), scope: :user
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

    it "should exchange and save long-lived Threads credentials" do
      stub_request(:get, "https://graph.threads.net/access_token")
        .with(query: {
          "grant_type" => "th_exchange_token",
          "client_secret" => "threadsappsecret",
          "access_token" => "short-lived-threads-token"
        })
        .to_return(
          status: 200,
          body: {
            access_token: "long-lived-threads-token",
            token_type: "bearer",
            expires_in: 5_183_944
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      request.env["omniauth.auth"] = JSON.parse(File.read(Rails.root.join("spec/data_fixtures/services/threads.json")))

      expect {
        get :threads
      }.to change { users(:bob).services.count }.by(1)

      service = users(:bob).services.find_by!(provider: "threads", uid: "3141592653")
      expect(service.name).to eq("threads-user")
      expect(service.uid).to eq("3141592653")
      expect(service.token).to eq("long-lived-threads-token")
      expect(service.options[:username]).to eq("threads-user")
    end
  end
end
