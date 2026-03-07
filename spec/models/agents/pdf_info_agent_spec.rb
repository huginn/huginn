require "rails_helper"

describe Agents::PdfInfoAgent do
  let(:agent) do
    _agent = Agents::PdfInfoAgent.new(name: "PDF Info Agent")
    _agent.user = users(:bob)
    _agent.sources << agents(:bob_website_agent)
    _agent.save!
    _agent
  end

  def stub_faraday(url, pdf_path)
    stub_request(:get, url).to_return(
      body: File.binread(pdf_path),
      status: 200,
    )
  end

  describe "#receive" do
    before do
      @event = Event.new(payload: { "url" => "http://example.com/test.pdf" })
    end

    it "should extract PDF info and create an event" do
      stub_faraday("http://example.com/test.pdf", Rails.root.join("spec/data_fixtures/test.pdf"))

      expect {
        agent.receive([@event])
      }.to change { Event.count }.by(1)

      event = Event.last
      expect(event.payload["Title"]).to eq("Test PDF")
      expect(event.payload["Author"]).to eq("Huginn")
      expect(event.payload["CreationDate"]).to eq("Fri Aug  2 05:32:50 2013")
      expect(event.payload["Pages"]).to eq("1")
      expect(event.payload["Page size"]).to eq("612 x 792 pts")
      expect(event.payload["PDF version"]).to eq("1.4")
      expect(event.payload["url"]).to eq("http://example.com/test.pdf")
    end

    it "should handle multi-page PDFs" do
      stub_faraday("http://example.com/test.pdf", Rails.root.join("spec/data_fixtures/test_multi_page.pdf"))

      expect {
        agent.receive([@event])
      }.to change { Event.count }.by(1)

      event = Event.last
      expect(event.payload["Title"]).to eq("Multi-page Test")
      expect(event.payload["Author"]).to eq("Huginn")
      expect(event.payload["Pages"]).to eq("2")
      expect(event.payload["Page size"]).to eq("612 x 792 pts")
      expect(event.payload["PDF version"]).to eq("1.5")
    end

    it "should not act on non-HTTP URLs" do
      @event.payload["url"] = "ftp://example.com/test.pdf"

      expect {
        agent.receive([@event])
      }.not_to change { Event.count }
    end
  end
end
