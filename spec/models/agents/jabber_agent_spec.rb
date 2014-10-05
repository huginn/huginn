require 'spec_helper'

describe Agents::JabberAgent do
  let(:sent) { [] }
  let(:config) {
    {
      jabber_server: '127.0.0.1',
      jabber_port: '5222',
      jabber_sender: 'foo@localhost',
      jabber_receiver: 'bar@localhost',
      jabber_password: 'password',
      message: 'Warning! {{title}} - {{url}}',
      expected_receive_period_in_days: '2'
    }
  }

  let(:agent) do
    Agents::JabberAgent.new(name: 'Jabber Agent', options: config).tap do |a|
      a.user = users(:bob)
      a.save!
    end
  end

  let(:event) do
    Event.new.tap do |e|
      e.agent = agents(:bob_weather_agent)
      e.payload = { :title => 'Weather Alert!', :url => 'http://www.weather.com/' }
      e.save!
    end
  end

  before do
    stub.any_instance_of(Agents::JabberAgent).deliver { |message| sent << message }
  end

  describe "#working?" do
    it "checks if events have been received within the expected receive period" do
      expect(agent).not_to be_working # No events received
      Agents::JabberAgent.async_receive agent.id, [event.id]
      expect(agent.reload).to be_working # Just received events
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(agent.reload).not_to be_working # More time has passed than the expected receive period without any new events
    end
  end

  describe "validation" do
    before do
      expect(agent).to be_valid
    end

    it "should validate presence of of jabber_server" do
      agent.options[:jabber_server] = ""
      expect(agent).not_to be_valid
    end

    it "should validate presence of jabber_sender" do
      agent.options[:jabber_sender] = ""
      expect(agent).not_to be_valid
    end

    it "should validate presence of jabber_receiver" do
      agent.options[:jabber_receiver] = ""
      expect(agent).not_to be_valid
    end
  end

  describe "receive" do
    it "should send an IM for each event" do
      event2 = Event.new.tap do |e|
        e.agent = agents(:bob_weather_agent)
        e.payload = { :title => 'Another Weather Alert!', :url => 'http://www.weather.com/we-are-screwed' }
        e.save!
      end

      agent.receive([event, event2])
      expect(sent).to eq([ 'Warning! Weather Alert! - http://www.weather.com/',
                       'Warning! Another Weather Alert! - http://www.weather.com/we-are-screwed'])
    end
  end
end
