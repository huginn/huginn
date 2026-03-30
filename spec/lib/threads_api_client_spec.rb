require "rails_helper"

describe ThreadsApiClient do
  subject(:client) { described_class.new(access_token_provider: -> { "token" }) }

  it "adds the access token to account requests" do
    stub_request(:get, "https://graph.threads.net/v1.0/me")
      .with(query: { access_token: "token", fields: "id" })
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { id: "123" }.to_json
      )

    expect(client.account(fields: "id")).to eq(id: "123")
  end

  it "returns posts across paginated responses" do
    stub_request(:get, "https://graph.threads.net/v1.0/me/threads")
      .with(query: {
        access_token: "token",
        fields: "id,timestamp",
        limit: "25",
      })
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          data: [{ id: "1002", timestamp: "2024-01-02T12:00:00+0000" }],
          paging: { cursors: { after: "cursor-1" } },
        }.to_json
      )

    stub_request(:get, "https://graph.threads.net/v1.0/me/threads")
      .with(query: {
        access_token: "token",
        after: "cursor-1",
        fields: "id,timestamp",
        limit: "25",
      })
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          data: [{ id: "1001", timestamp: "2024-01-01T12:00:00+0000" }],
        }.to_json
      )

    expect(client.posts(user_id: "me", fields: "id,timestamp", limit: "25")).to eq(
      [
        { id: "1002", timestamp: "2024-01-02T12:00:00+0000" },
        { id: "1001", timestamp: "2024-01-01T12:00:00+0000" },
      ]
    )
  end

  it "adds the access token to text post creation requests" do
    stub_request(:post, "https://graph.threads.net/v1.0/me/threads")
      .with(body: { access_token: "token", media_type: "TEXT", text: "hello" })
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { id: "creation-123" }.to_json
      )

    expect(client.create_text_post(text: "hello")).to eq(id: "creation-123")
  end

  it "raises the Threads API error message" do
    stub_request(:delete, "https://graph.threads.net/v1.0/123")
      .with(query: { access_token: "token" })
      .to_return(
        status: 400,
        headers: { "Content-Type" => "application/json" },
        body: {
          error: {
            message: "Unsupported post request",
          },
        }.to_json,
      )

    expect {
      client.delete_post(thread_id: "123")
    }.to raise_error(StandardError, "Unsupported post request")
  end
end
