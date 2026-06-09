require "rails_helper"

describe RaindropApiClient do
  subject(:client) { described_class.new(access_token_provider: -> { "token" }) }

  describe "#raindrops" do
    it "returns raindrops from a collection" do
      stub_request(:get, "https://api.raindrop.io/rest/v1/raindrops/0")
        .with(
          query: {
            page: "0",
            perpage: "50",
            search: "tag:reading",
            sort: "-created",
            nested: "true",
          },
          headers: {
            "Authorization" => "Bearer token",
          }
        )
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            result: true,
            items: [
              {
                _id: 123,
                link: "https://example.com/",
                title: "Example",
              },
            ],
          }.to_json
        )

      expect(client.raindrops(collection_id: 0, search: "tag:reading", nested: true)).to eq(
        [
          {
            _id: 123,
            link: "https://example.com/",
            title: "Example",
          },
        ]
      )
    end
  end

  describe "#create_raindrop" do
    it "creates a raindrop" do
      stub_request(:post, "https://api.raindrop.io/rest/v1/raindrop")
        .with(
          body: {
            link: "https://example.com/",
            title: "Example",
          }.to_json,
          headers: {
            "Authorization" => "Bearer token",
            "Content-Type" => "application/json",
          }
        )
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            result: true,
            item: {
              _id: 123,
              link: "https://example.com/",
              title: "Example",
            },
          }.to_json
        )

      expect(client.create_raindrop(link: "https://example.com/", title: "Example")).to eq(
        {
          _id: 123,
          link: "https://example.com/",
          title: "Example",
        }
      )
    end

    it "raises the Raindrop API error message" do
      stub_request(:post, "https://api.raindrop.io/rest/v1/raindrop")
        .to_return(
          status: 400,
          headers: { "Content-Type" => "application/json" },
          body: {
            result: false,
            errorMessage: "link is invalid",
          }.to_json
        )

      expect {
        client.create_raindrop(link: "not a url")
      }.to raise_error(StandardError, "link is invalid")
    end
  end
end
