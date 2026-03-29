require "rails_helper"

describe DropboxApiClient do
  subject(:client) { described_class.new(access_token: "token") }

  let(:headers) do
    {
      "Authorization" => "Bearer token",
      "Content-Type" => "application/json"
    }
  end

  describe "#ls" do
    it "returns file entries across paginated responses" do
      stub_request(:post, "https://api.dropboxapi.com/2/files/list_folder")
        .with(body: { path: "/watched" }.to_json, headers:)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            entries: [
              { ".tag" => "file", "path_display" => "/watched/a.txt", "rev" => "1", "server_modified" => "2026-01-01T00:00:00Z" },
              { ".tag" => "folder", "path_display" => "/watched/subdir" }
            ],
            cursor: "cursor-1",
            has_more: true
          }.to_json
        )

      stub_request(:post, "https://api.dropboxapi.com/2/files/list_folder/continue")
        .with(body: { cursor: "cursor-1" }.to_json, headers:)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            entries: [
              { ".tag" => "file", "path_lower" => "/watched/b.txt", "rev" => "2", "server_modified" => "2026-01-02T00:00:00Z" }
            ],
            has_more: false
          }.to_json
        )

      expect(client.ls("/watched")).to eq(
        [
          { "path" => "/watched/a.txt", "rev" => "1", "modified" => "2026-01-01T00:00:00Z" },
          { "path" => "/watched/b.txt", "rev" => "2", "modified" => "2026-01-02T00:00:00Z" }
        ]
      )
    end

    it "normalizes the root path to an empty string" do
      stub_request(:post, "https://api.dropboxapi.com/2/files/list_folder")
        .with(body: { path: "" }.to_json, headers:)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { entries: [], has_more: false }.to_json
        )

      expect(client.ls("/")).to eq([])
    end
  end

  describe "#temporary_url_for" do
    it "normalizes the response url key" do
      stub_request(:post, "https://api.dropboxapi.com/2/files/get_temporary_link")
        .with(body: { path: "/watched/a.txt" }.to_json, headers:)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            link: "https://dl.dropboxusercontent.com/apitl/1/example",
            metadata: { name: "a.txt" }
          }.to_json
        )

      expect(client.temporary_url_for("/watched/a.txt")).to eq(
        {
          "url" => "https://dl.dropboxusercontent.com/apitl/1/example",
          "metadata" => { "name" => "a.txt" }
        }
      )
    end
  end

  describe "#permanent_url_for" do
    it "creates a shared link and forces dl=1" do
      stub_request(:post, "https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings")
        .with(body: { path: "/watched/a.txt" }.to_json, headers:)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            url: "https://www.dropbox.com/s/example/a.txt?dl=0",
            name: "a.txt"
          }.to_json
        )

      expect(client.permanent_url_for("/watched/a.txt")).to eq(
        {
          "url" => "https://www.dropbox.com/s/example/a.txt?dl=1",
          "name" => "a.txt"
        }
      )
    end

    it "reuses an existing shared link when Dropbox reports one already exists" do
      stub_request(:post, "https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings")
        .with(body: { path: "/watched/a.txt" }.to_json, headers:)
        .to_return(
          status: 409,
          headers: { "Content-Type" => "application/json" },
          body: {
            error_summary: "shared_link_already_exists/.."
          }.to_json
        )

      stub_request(:post, "https://api.dropboxapi.com/2/sharing/list_shared_links")
        .with(body: { path: "/watched/a.txt", direct_only: true }.to_json, headers:)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            links: [
              { "url" => "https://www.dropbox.com/s/example/a.txt?raw=1", "path_lower" => "/watched/a.txt", "name" => "a.txt" }
            ]
          }.to_json
        )

      expect(client.permanent_url_for("/watched/a.txt")).to eq(
        {
          "url" => "https://www.dropbox.com/s/example/a.txt?raw=1&dl=1",
          "path_lower" => "/watched/a.txt",
          "name" => "a.txt"
        }
      )
    end
  end
end
