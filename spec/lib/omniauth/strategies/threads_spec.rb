require "spec_helper"
require "webmock/rspec"
require_relative "../../../../lib/omniauth/strategies/threads"

# rubocop:disable Metrics/BlockLength
describe OmniAuth::Strategies::Threads do
  let(:strategy) { described_class.new(nil, "threadsappid", "threadssecret") }
  let(:callback_url) { "https://agents.akinori.org/auth/threads/callback" }
  let(:request) { double(params: { "code" => "auth-code", "state" => "request-state" }) }

  describe "#client" do
    it "authenticates token requests with request body params" do
      expect(strategy.client.options[:auth_scheme]).to eq(:request_body)
    end
  end

  describe "#callback_url" do
    before do
      allow(strategy).to receive(:full_host).and_return("https://agents.akinori.org")
      allow(strategy).to receive(:callback_path).and_return("/auth/threads/callback")
    end

    it "does not include query params from the callback request" do
      expect(strategy.send(:callback_url)).to eq(callback_url)
    end
  end

  describe "#build_access_token" do
    before do
      allow(strategy).to receive(:request).and_return(request)
      allow(strategy).to receive(:full_host).and_return("https://agents.akinori.org")
      allow(strategy).to receive(:callback_path).and_return("/auth/threads/callback")
    end

    it "sends client credentials in the token exchange body" do
      stub_request(:post, "https://graph.threads.net/oauth/access_token")
        .with(body: {
          "grant_type" => "authorization_code",
          "code" => "auth-code",
          "redirect_uri" => callback_url,
          "client_id" => "threadsappid",
          "client_secret" => "threadssecret",
        })
        .to_return(
          status: 200,
          body: {
            access_token: "short-lived-threads-token",
            token_type: "bearer",
            expires_in: 3600,
            user_id: "3141592653",
          }.to_json,
          headers: { "Content-Type" => "application/json" },
        )

      token = strategy.send(:build_access_token)
      expect(token.token).to eq("short-lived-threads-token")
    end
  end
end
# rubocop:enable Metrics/BlockLength
