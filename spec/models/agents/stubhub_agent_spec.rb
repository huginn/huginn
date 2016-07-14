require 'rails_helper'

describe Agents::StubhubAgent do

  let(:name) { 'Agent Name' }
  let(:url) { 'https://www.stubhub.com/event/name-1-1-2014-12345' }
  let(:parsed_body) { JSON.parse(body)['response']['docs'][0] }
  let(:valid_params) { { 'url' => parsed_body['url'] } }
  let(:body) { File.read(Rails.root.join('spec/data_fixtures/stubhub_data.json')) }
  let(:stubhub_event_id) { 12345 }
  let(:response_payload) { {
                            'url' => url,
                            'name' => parsed_body['seo_description_en_US'],
                            'date' => parsed_body['event_date_local'],
                            'max_price' => parsed_body['maxPrice'],
                            'min_price' => parsed_body['minPrice'],
                            'total_postings' => parsed_body['totalPostings'],
                            'total_tickets' => parsed_body['totalTickets'],
                            'venue_name' => parsed_body['venue_name']
                            } }

  before do
      stub_request(:get, "https://www.stubhub.com/listingCatalog/select/?q=%2B%20stubhubDocumentType:event%0D%0A%2B%20event_id:#{stubhub_event_id}%0D%0A&rows=10&start=0&wt=json").
         to_return(:status => 200, :body => body, :headers => {})

    @stubhub_agent = described_class.new(name: name, options: valid_params)
    @stubhub_agent.user = users(:jane)
    @stubhub_agent.save!
  end


  describe "#check" do

    it 'should create an event' do
      expect { @stubhub_agent.check }.to change { Event.count }.by(1)
    end

    it 'should properly parse the response' do
      event = @stubhub_agent.check
      expect(event.payload).to eq(response_payload)
    end
  end

  describe "validations" do
    before do
      expect(@stubhub_agent).to be_valid
    end

    it "should require a url" do
      @stubhub_agent.options['url'] = nil
      expect(@stubhub_agent).not_to be_valid
    end

  end

  describe "#working?" do
    it "checks if events have been received within the expected receive period" do
      expect(@stubhub_agent).not_to be_working

      Agents::StubhubAgent.async_check @stubhub_agent.id
      expect(@stubhub_agent.reload).to be_working
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(@stubhub_agent.reload).not_to be_working
    end
  end
end
