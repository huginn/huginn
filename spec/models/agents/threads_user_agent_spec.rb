require "rails_helper"

describe Agents::ThreadsUserAgent do
  before do
    @agent = Agents::ThreadsUserAgent.new(
      name: "Threads watcher",
      options: {
        user_id: "me",
        limit: "25",
        expected_update_period_in_days: "2",
        starting_at: "Jan 01 00:00:01 +0000 2020",
      },
    )
    @agent.service = services(:threads)
    @agent.user = users(:bob)
    @agent.save!
  end

  describe "#check" do
    it "creates events for posts returned by the Threads API" do
      stub_request(:get, "https://graph.threads.net/v1.0/me/threads")
        .with(query: {
          "fields" => ThreadsConcern::THREADS_DEFAULT_FIELDS.join(","),
          "limit" => "25",
          "access_token" => "long-lived-threads-token",
        })
        .to_return(
          status: 200,
          body: File.read(Rails.root.join("spec/data_fixtures/threads_user_posts.json")),
          headers: { "Content-Type" => "application/json" }
        )

      expect { @agent.check }.to change { Event.count }.by(2)

      created_events = @agent.events.last(2)
      expect(created_events.map { |event| event.payload["id"] }.sort).to eq(%w[1001 1002])
      expect(Time.zone.parse(@agent.memory["since"]).utc.iso8601).to eq("2024-01-02T12:00:00Z")
      expect(@agent.memory["since_ids"]).to eq(["1002"])
    end

    it "does not emit duplicates for posts already seen at the latest timestamp" do
      @agent.memory["since"] = "2024-01-02T12:00:00+00:00"
      @agent.memory["since_ids"] = ["1002"]

      stub_request(:get, "https://graph.threads.net/v1.0/me/threads")
        .with(query: {
          "fields" => ThreadsConcern::THREADS_DEFAULT_FIELDS.join(","),
          "limit" => "25",
          "since" => "2024-01-02T12:00:00+00:00",
          "access_token" => "long-lived-threads-token",
        })
        .to_return(
          status: 200,
          body: File.read(Rails.root.join("spec/data_fixtures/threads_user_posts.json")),
          headers: { "Content-Type" => "application/json" }
        )

      expect { @agent.check }.not_to(change { Event.count })
    end

    it "creates events for posts returned on later pages" do
      stub_request(:get, "https://graph.threads.net/v1.0/me/threads")
        .with(query: {
          "fields" => ThreadsConcern::THREADS_DEFAULT_FIELDS.join(","),
          "limit" => "25",
          "access_token" => "long-lived-threads-token",
        })
        .to_return(
          status: 200,
          body: {
            data: [
              {
                id: "1003",
                timestamp: "2024-01-03T12:00:00+0000",
                username: "threads-user",
              },
            ],
            paging: {
              cursors: {
                after: "cursor-1",
              },
            },
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:get, "https://graph.threads.net/v1.0/me/threads")
        .with(query: {
          "fields" => ThreadsConcern::THREADS_DEFAULT_FIELDS.join(","),
          "limit" => "25",
          "after" => "cursor-1",
          "access_token" => "long-lived-threads-token",
        })
        .to_return(
          status: 200,
          body: {
            data: [
              {
                id: "1002",
                timestamp: "2024-01-02T12:00:00+0000",
                username: "threads-user",
              },
            ],
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { @agent.check }.to change { Event.count }.by(2)

      created_events = @agent.events.last(2)
      expect(created_events.map { |event| event.payload["id"] }.sort).to eq(%w[1002 1003])
      expect(Time.zone.parse(@agent.memory["since"]).utc.iso8601).to eq("2024-01-03T12:00:00Z")
      expect(@agent.memory["since_ids"]).to eq(["1003"])
    end
  end
end
