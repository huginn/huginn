require 'rails_helper'

describe Agents::JsonParseAgent do
  before(:each) do
    @checker = Agents::JsonParseAgent.new(:name => "somename", :options => Agents::JsonParseAgent.new.default_options)
    @checker.user = users(:jane)
    @checker.save!
  end

  it "event description does not throw an exception" do
    expect(@checker.event_description).to include('parsed')
  end

  describe "validating" do
    before do
      expect(@checker).to be_valid
    end

    it "requires data to be present" do
      @checker.options['data'] = ''
      expect(@checker).not_to be_valid
    end

    it "requires data_key to be set" do
      @checker.options['data_key'] = ''
      expect(@checker).not_to be_valid
    end
  end

  context '#working' do
    it 'is not working without having received an event' do
      expect(@checker).not_to be_working
    end

    it 'is working after receiving an event without error' do
      @checker.last_receive_at = Time.now
      expect(@checker).to be_working
    end
  end

  describe "#receive" do
    it "parses valid JSON" do
      event = Event.new(payload: { data: '{"test": "data"}' } )
      expect { @checker.receive([event]) }.to change(Event, :count).by(1)
    end

    it "writes to the error log when the JSON could not be parsed" do
      event = Event.new(payload: { data: '{"test": "data}' } )
      expect { @checker.receive([event]) }.to change(AgentLog, :count).by(1)
    end

    it "support merge mode" do
      @checker.options[:mode] = "merge"
      event = Event.new(payload: { data: '{"test": "data"}', extra: 'a' } )
      expect { @checker.receive([event]) }.to change { Event.count }.by(1)
      last_payload = Event.last.payload
      expect(last_payload['extra']).to eq('a')
    end
  end
end
