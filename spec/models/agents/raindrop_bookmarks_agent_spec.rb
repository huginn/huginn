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

  def stub_raindrops(body = File.read(Rails.root.join("spec/data_fixtures/raindrop_raindrops.json")))
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
        body:,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def raindrop_item(id, created)
    {
      _id: id,
      link: "https://example.com/#{id}",
      title: "Example #{id}",
      created:,
      lastUpdate: created,
      collection: { "$id": 0 },
      tags: [],
    }
  end

  describe "#check" do
    it "creates events for raindrops returned by the Raindrop API" do
      stub_raindrops

      expect { @agent.check }.to change { Event.count }.by(2)

      created_events = @agent.events.last(2)
      expect(created_events.map { |event| event.payload["_id"] }.sort).to eq([1001, 1002])
      expect(Time.zone.parse(@agent.memory["since"]).utc.iso8601).to eq("2024-01-02T12:00:00Z")
      expect(@agent.memory["since_ids"]).to eq(["1002"])
    end

    it "does not emit duplicates for raindrops already seen at the latest timestamp" do
      @agent.memory["since"] = "2024-01-02T12:00:00+00:00"
      @agent.memory["since_ids"] = ["1002"]

      stub_raindrops

      expect { @agent.check }.not_to(change { Event.count })
    end

    it "does not emit duplicates across runs when created timestamps have fractional seconds" do
      stub_raindrops({
        result: true,
        items: [raindrop_item(1003, "2024-01-03T12:00:00.500Z")],
      }.to_json)

      expect { @agent.check }.to change { Event.count }.by(1)
      expect(Time.zone.parse(@agent.memory["since"])).to eq(Time.zone.parse("2024-01-03T12:00:00.500Z"))

      fresh_agent = Agent.find(@agent.id)
      expect { fresh_agent.check }.not_to(change { Event.count })
    end

    it "keeps previously seen ids when a new raindrop shares the latest timestamp" do
      @agent.memory["since"] = "2024-01-02T12:00:00.000Z"
      @agent.memory["since_ids"] = ["1002"]
      @agent.save!

      stub_raindrops({
        result: true,
        items: [
          raindrop_item(1002, "2024-01-02T12:00:00.000Z"),
          raindrop_item(1004, "2024-01-02T12:00:00.000Z"),
        ],
      }.to_json)

      expect { @agent.check }.to change { Event.count }.by(1)
      expect(@agent.events.last.payload["_id"]).to eq(1004)
      expect(@agent.memory["since_ids"]).to match_array(["1002", "1004"])

      fresh_agent = Agent.find(@agent.id)
      expect { fresh_agent.check }.not_to(change { Event.count })
    end
  end
end
