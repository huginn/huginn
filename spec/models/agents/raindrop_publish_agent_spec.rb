require "rails_helper"

describe Agents::RaindropPublishAgent do
  before do
    @agent = Agents::RaindropPublishAgent.new(
      name: "Raindrop publisher",
      options: {
        link: "{{url}}",
        title: "{{title}}",
        tags: "reading, huginn",
        collection_id: "10",
        please_parse: "true",
      }
    )
    @agent.service = services(:raindrop)
    @agent.user = users(:bob)
    @agent.save!

    @event = Event.create!(
      agent: agents(:bob_weather_agent),
      payload: {
        url: "https://example.com/",
        title: "Example",
      }
    )
  end

  describe "#receive" do
    it "creates a raindrop and emits an event" do
      stub_request(:post, "https://api.raindrop.io/rest/v1/raindrop")
        .with(
          headers: {
            "Authorization" => "Bearer raindrop-access-token",
          }
        )
        .to_return(
          status: 200,
          body: {
            result: true,
            item: {
              _id: 123,
              link: "https://example.com/",
              title: "Example",
            },
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { @agent.receive([@event]) }.to change { @agent.events.count }.by(1)

      payload = @agent.events.last.payload
      expect(payload["success"]).to eq(true)
      expect(payload["raindrop"]["_id"]).to eq(123)
      expect(payload["raindrop"]["link"]).to eq("https://example.com/")
    end

    it "uses the Raindrop API error message when publishing fails" do
      stub_request(:post, "https://api.raindrop.io/rest/v1/raindrop")
        .to_return(
          status: 400,
          body: {
            result: false,
            errorMessage: "link is invalid",
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { @agent.receive([@event]) }.to change { @agent.events.count }.by(1)

      payload = @agent.events.last.payload
      expect(payload["success"]).to eq(false)
      expect(payload["error"]).to eq("link is invalid")
      expect(payload["failed_link"]).to eq("https://example.com/")
    end
  end
end
