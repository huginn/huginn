# frozen_string_literal: true

require "rails_helper"

# rubocop:disable Metrics/BlockLength
describe TumblrApiClient do
  subject(:client) do
    described_class.new(
      consumer_key: "consumer-key",
      consumer_secret: "consumer-secret",
      oauth_token: "oauth-token",
      oauth_token_secret: "oauth-token-secret"
    )
  end

  it "fetches blog likes with the api key and oauth header" do
    stub_request(:get, "https://api.tumblr.com/v2/blog/wendys.tumblr.com/likes")
      .with(
        query: { after: "123", api_key: "consumer-key" },
        headers: {
          "Accept" => "application/json",
          "Authorization" => /^OAuth /,
          "User-Agent" => "Huginn/TumblrApiClient",
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          meta: { status: 200, msg: "OK" },
          response: { "liked_posts" => [{ "id" => 1 }] },
        }.to_json,
      )

    expect(client.blog_likes("wendys.tumblr.com", after: 123)).to eq(
      liked_posts: [{ id: 1 }]
    )
  end

  it "creates text posts on the standard post endpoint" do
    stub_request(:post, "https://api.tumblr.com/v2/blog/huginnbot.tumblr.com/post")
      .with(
        body: { title: "Hello", body: "World", type: "text" },
        headers: {
          "Accept" => "application/json",
          "Authorization" => /^OAuth /,
          "Content-Type" => "application/x-www-form-urlencoded",
          "User-Agent" => "Huginn/TumblrApiClient",
        }
      )
      .to_return(
        status: 201,
        headers: { "Content-Type" => "application/json" },
        body: {
          meta: { status: 201, msg: "Created" },
          response: { "id" => "5" },
        }.to_json,
      )

    expect(client.text("huginnbot.tumblr.com", title: "Hello", body: "World")).to eq(id: "5")
  end

  it "posts reblogs to the reblog endpoint" do
    stub_request(:post, "https://api.tumblr.com/v2/blog/huginnbot.tumblr.com/post/reblog")
      .with(
        body: { id: "5", reblog_key: "abc123", comment: "Again" },
        headers: { "Authorization" => /^OAuth / }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          meta: { status: 200, msg: "OK" },
          response: { "id" => "10" },
        }.to_json,
      )

    expect(client.reblog("huginnbot.tumblr.com", id: "5", reblog_key: "abc123", comment: "Again")).to eq(id: "10")
  end

  it "returns Tumblr meta errors in the legacy format" do
    stub_request(:get, "https://api.tumblr.com/v2/blog/notfound.tumblr.com/likes")
      .with(query: { after: "0", api_key: "consumer-key" })
      .to_return(
        status: 404,
        headers: { "Content-Type" => "application/json" },
        body: {
          meta: { status: 404, msg: "Not Found" },
        }.to_json,
      )

    expect(client.blog_likes("notfound.tumblr.com", after: 0)).to eq(
      status: 404,
      msg: "Not Found"
    )
  end
end
# rubocop:enable Metrics/BlockLength
