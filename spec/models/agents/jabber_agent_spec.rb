require 'rails_helper'

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

  context "#start_worker?" do
    it "starts when connect_to_receiver is truthy" do
      agent.options[:connect_to_receiver] = 'true'
      expect(agent.start_worker?).to be_truthy
    end

    it "does not starts when connect_to_receiver is not truthy" do
      expect(agent.start_worker?).to be_falsy
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

  describe Agents::JabberAgent::Worker do
    before(:each) do
      @worker = Agents::JabberAgent::Worker.new(agent: agent)
      @worker.setup
      stub.any_instance_of(Jabber::Client).connect
      stub.any_instance_of(Jabber::Client).auth
    end

    it "runs" do
      agent.options[:jabber_receiver] = 'someJID'
      mock.any_instance_of(Jabber::MUC::SimpleMUCClient).join('someJID')
      @worker.run
    end

    it "stops" do
      @worker.instance_variable_set(:@client, @worker.client)
      mock.any_instance_of(Jabber::Client).close
      mock.any_instance_of(Jabber::Client).stop
      mock(@worker).thread { mock!.terminate }
      @worker.stop
    end

    context "#message_handler" do
      it "it ignores messages for the first seconds" do
        @worker.instance_variable_set(:@started_at, Time.now)
        expect { @worker.message_handler(:on_message, [123456, 'nick', 'hello']) }
          .to change { agent.events.count }.by(0)
      end

      it "creates events" do
        @worker.instance_variable_set(:@started_at, Time.now - 10.seconds)
        expect { @worker.message_handler(:on_message, [123456, 'nick', 'hello']) }
          .to change { agent.events.count }.by(1)
        event = agent.events.last
        expect(event.payload).to eq({'event' => 'on_message', 'time' => 123456, 'nick' => 'nick', 'message' => 'hello'})
      end
    end

    context "#normalize_args" do
      it "handles :on_join and :on_leave" do
        time, nick, message = @worker.send(:normalize_args, :on_join, [123456, 'nick'])
        expect(time).to eq(123456)
        expect(nick).to eq('nick')
        expect(message).to be_nil
      end

      it "handles :on_message and :on_leave" do
        time, nick, message = @worker.send(:normalize_args, :on_message, [123456, 'nick', 'hello'])
        expect(time).to eq(123456)
        expect(nick).to eq('nick')
        expect(message).to eq('hello')
      end

      it "handles :on_room_message" do
        time, nick, message = @worker.send(:normalize_args, :on_room_message, [123456, 'hello'])
        expect(time).to eq(123456)
        expect(nick).to be_nil
        expect(message).to eq('hello')
      end
    end
  end
end
