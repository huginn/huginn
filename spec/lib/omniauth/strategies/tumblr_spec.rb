# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/omniauth/strategies/tumblr"

# rubocop:disable Metrics/BlockLength
describe OmniAuth::Strategies::Tumblr do
  let(:strategy) { described_class.new(nil, "tumblrappid", "tumblrsecret") }
  let(:access_token) { instance_double(OAuth::AccessToken) }

  describe "client options" do
    it "uses Tumblr's OAuth 1 endpoints" do
      expect(strategy.options.client_options[:site]).to eq("https://www.tumblr.com")
      expect(strategy.options.client_options[:request_token_path]).to eq("/oauth/request_token")
      expect(strategy.options.client_options[:access_token_path]).to eq("/oauth/access_token")
      expect(strategy.options.client_options[:authorize_path]).to eq("/oauth/authorize")
    end
  end

  describe "#raw_info" do
    let(:response) do
      double(body: {
        response: {
          user: {
            name: "huginnbot",
            blogs: [{ url: "https://huginnbot.tumblr.com/" }],
          },
        },
      }.to_json)
    end

    before do
      allow(strategy).to receive(:access_token).and_return(access_token)
      allow(access_token).to receive(:get).with("https://api.tumblr.com/v2/user/info").and_return(response)
    end

    it "returns the Tumblr user payload" do
      expect(strategy.raw_info).to eq(
        name: "huginnbot",
        blogs: [{ url: "https://huginnbot.tumblr.com/" }]
      )
    end
  end

  describe "#avatar_url" do
    let(:response) do
      double(body: {
        response: {
          avatar_url: "https://secure.assets.tumblr.com/avatar.png",
        },
      }.to_json)
    end

    before do
      allow(strategy).to receive(:raw_info).and_return(
        blogs: [{ url: "https://huginnbot.tumblr.com/" }]
      )
      allow(strategy).to receive(:access_token).and_return(access_token)
      allow(access_token).to receive(:get).with("https://api.tumblr.com/v2/blog/huginnbot.tumblr.com/avatar").and_return(response)
    end

    it "fetches the avatar URL from the Tumblr API" do
      expect(strategy.avatar_url).to eq("https://secure.assets.tumblr.com/avatar.png")
    end

    it "returns nil when no blog is available" do
      allow(strategy).to receive(:raw_info).and_return(blogs: [])

      expect(strategy.avatar_url).to be_nil
    end
  end
end
# rubocop:enable Metrics/BlockLength
