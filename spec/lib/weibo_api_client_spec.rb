require "rails_helper"
require "tempfile"

describe WeiboApiClient do
  subject(:client) { described_class.new(access_token: "token") }

  describe "#statuses" do
    it "fetches a user timeline" do
      stub_request(:get, "https://api.weibo.com/2/statuses/user_timeline.json")
        .with(query: { access_token: "token", uid: "123" })
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            statuses: [
              { id: 1, text: "hello" }
            ]
          }.to_json
        )

      response = client.statuses.user_timeline(uid: "123")

      expect(response.statuses.first.id).to eq(1)
      expect(response.statuses.first.as_json).to include("text" => "hello")
    end

    it "publishes a text status" do
      stub_request(:post, "https://api.weibo.com/2/statuses/update.json")
        .with(body: { access_token: "token", status: "hello world" })
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { id: 1 }.to_json)

      response = client.statuses.update("hello world")

      expect(response.id).to eq(1)
    end

    it "publishes a status with an uploaded image" do
      stub_request(:post, "https://api.weibo.com/2/statuses/upload.json")
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { id: 1 }.to_json)

      Tempfile.create(["upload", ".jpg"]) do |file|
        file.write("image")
        file.flush

        response = client.statuses.upload("hello world", file, content_type: "image/jpeg")

        expect(response.id).to eq(1)
      end
    end
  end
end
