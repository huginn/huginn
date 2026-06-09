require "spec_helper"
require "webmock/rspec"
require_relative "../../../../lib/omniauth/strategies/raindrop"

describe OmniAuth::Strategies::Raindrop do
  let(:strategy) { described_class.new(nil, "raindropclientid", "raindropclientsecret") }
  let(:callback_url) { "https://agents.akinori.org/auth/raindrop/callback" }
  let(:request) { double(params: { "code" => "auth-code", "state" => "request-state" }) }

  describe "#client" do
    it "uses Raindrop's API host for token requests" do
      expect(strategy.client.site).to eq("https://api.raindrop.io")
      expect(strategy.client.options[:authorize_url]).to eq("https://raindrop.io/oauth/authorize")
      expect(strategy.client.options[:token_url]).to eq("/v1/oauth/access_token")
    end
  end

  describe "#callback_url" do
    before do
      allow(strategy).to receive(:full_host).and_return("https://agents.akinori.org")
      allow(strategy).to receive(:callback_path).and_return("/auth/raindrop/callback")
    end

    it "does not include query params from the callback request" do
      expect(strategy.send(:callback_url)).to eq(callback_url)
    end
  end

  describe "#build_access_token" do
    before do
      allow(strategy).to receive(:request).and_return(request)
      allow(strategy).to receive(:full_host).and_return("https://agents.akinori.org")
      allow(strategy).to receive(:callback_path).and_return("/auth/raindrop/callback")
    end

    it "uses Raindrop's JSON token exchange" do
      stub_request(:post, "https://api.raindrop.io/v1/oauth/access_token")
        .with(
          body: hash_including({
            grant_type: "authorization_code",
            code: "auth-code",
            redirect_uri: callback_url,
            client_id: "raindropclientid",
            client_secret: "raindropclientsecret",
          }),
          headers: { "Content-Type" => /application\/json/ }
        )
        .to_return(
          status: 200,
          body: {
            access_token: "raindrop-access-token",
            refresh_token: "raindrop-refresh-token",
            token_type: "Bearer",
            expires_in: 1_209_599,
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      token = strategy.send(:build_access_token)
      expect(token.token).to eq("raindrop-access-token")
      expect(token.refresh_token).to eq("raindrop-refresh-token")
    end
  end
end
