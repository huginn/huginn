require "rails_helper"

describe Agents::RaindropBookmarksAgent do
  before do
    @agent = Agents::RaindropBookmarksAgent.new(
      name: "Raindrop bookmarks",
      options: {
        collection_id: "0",
        search: "",
        limit: "50",
        sort: "-created",
        nested: "false",
        expected_update_period_in_days: "2",
      }
    )
    @agent.service = services(:raindrop)
    @agent.user = users(:bob)
    @agent.save!
  end

  describe "#check" do
    it "creates events for raindrops returned by the Raindrop API" do
      stub_request(:get, "https://api.raindrop.io/rest/v1/raindrops/0")
        .with(
          query: {
            "page" => "0",
            "perpage" => "50",
            "sort" => "-created",
            "nested" => "false",
          },
          headers: {
            "Authorization" => "Bearer raindrop-access-token",
          }
        )
        .to_return(
          status: 200,
          body: File.read(Rails.root.join("spec/data_fixtures/raindrop_raindrops.json")),
          headers: { "Content-Type" => "application/json" }
        )

      expect { @agent.check }.to change { Event.count }.by(2)

      created_events = @agent.events.last(2)
      expect(created_events.map { |event| event.payload["_id"] }.sort).to eq([1001, 1002])
      expect(Time.zone.parse(@agent.memory["since"]).utc.iso8601).to eq("2024-01-02T12:00:00Z")
      expect(@agent.memory["since_ids"]).to eq(["1002"])
    end

    it "does not emit duplicates for raindrops already seen at the latest timestamp" do
      @agent.memory["since"] = "2024-01-02T12:00:00+00:00"
      @agent.memory["since_ids"] = ["1002"]

      stub_request(:get, "https://api.raindrop.io/rest/v1/raindrops/0")
        .with(
          query: {
            "page" => "0",
            "perpage" => "50",
            "sort" => "-created",
            "nested" => "false",
          },
          headers: {
            "Authorization" => "Bearer raindrop-access-token",
          }
        )
        .to_return(
          status: 200,
          body: File.read(Rails.root.join("spec/data_fixtures/raindrop_raindrops.json")),
          headers: { "Content-Type" => "application/json" }
        )

      expect { @agent.check }.not_to(change { Event.count })
    end
  end
end
