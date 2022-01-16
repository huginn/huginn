require 'rails_helper'

describe Agents::PdfInfoAgent do
  let(:agent) do
    _agent = Agents::PdfInfoAgent.new(name: "PDF Info Agent")
    _agent.user = users(:bob)
    _agent.sources << agents(:bob_website_agent)
    _agent.save!
    _agent
  end

  describe "#receive" do
    before do
      @event = Event.new(payload: {'url' => 'http://mypdf.com'})
    end

    it "should call HyPDF" do
      expect {
        expect(agent).to receive(:open).with('http://mypdf.com') { "data" }
        expect(HyPDF).to receive(:pdfinfo).with('data') { {title: "Huginn"} }
        agent.receive([@event])
      }.to change { Event.count }.by(1)
      event = Event.last
      expect(event.payload[:title]).to eq('Huginn')
    end
  end
end
