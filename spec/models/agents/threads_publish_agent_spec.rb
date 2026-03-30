require "rails_helper"

describe Agents::ThreadsPublishAgent do
  before do
    @agent = Agents::ThreadsPublishAgent.new(
      name: "Threads publisher",
      options: {
        message: "{{text}}",
        expected_update_period_in_days: "2",
      },
    )
    @agent.service = services(:threads)
    @agent.user = users(:bob)
    @agent.save!

    @event = Event.create!(
      agent: agents(:bob_weather_agent),
      payload: { text: "Hello Threads" }
    )
  end

  describe "#receive" do
    it "publishes a text post and emits an event" do
      stub_request(:post, "https://graph.threads.net/v1.0/me/threads")
        .with(body: {
          "media_type" => "TEXT",
          "text" => "Hello Threads",
          "reply_control" => "everyone",
          "access_token" => "long-lived-threads-token",
        })
        .to_return(
          status: 200,
          body: { id: "creation-123" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "https://graph.threads.net/v1.0/3141592653/threads_publish")
        .with(body: {
          "creation_id" => "creation-123",
          "access_token" => "long-lived-threads-token",
        })
        .to_return(
          status: 200,
          body: { id: "thread-456" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { @agent.receive([@event]) }.to change { @agent.events.count }.by(1)

      payload = @agent.events.last.payload
      expect(payload["success"]).to eq(true)
      expect(payload["published_post"]).to eq("Hello Threads")
      expect(payload["published_thread_id"]).to eq("thread-456")
      expect(payload["creation_id"]).to eq("creation-123")
    end

    it "uses the Threads API error message when publishing fails" do
      stub_request(:post, "https://graph.threads.net/v1.0/me/threads")
        .with(body: {
          "media_type" => "TEXT",
          "text" => "Hello Threads",
          "reply_control" => "everyone",
          "access_token" => "long-lived-threads-token",
        })
        .to_return(
          status: 400,
          body: {
            error: {
              message: "Application does not have permission for this action",
            },
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { @agent.receive([@event]) }.to change { @agent.events.count }.by(1)

      payload = @agent.events.last.payload
      expect(payload["success"]).to eq(false)
      expect(payload["error"]).to eq("Application does not have permission for this action")
      expect(payload["failed_post"]).to eq("Hello Threads")
    end
  end
end
