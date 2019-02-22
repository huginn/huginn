# encoding: utf-8

require 'rails_helper'

describe Agents::LiquidOutputAgent do
  let(:agent) do
    _agent = Agents::LiquidOutputAgent.new(:name => 'My Data Output Agent')
    _agent.options = _agent.default_options.merge('secret' => 'secret1', 'events_to_show' => 3)
    _agent.options['secret'] = "a secret"
    _agent.user = users(:bob)
    _agent.sources << agents(:bob_website_agent)
    _agent.save!
    _agent
  end

  describe "#working?" do
    it "checks if events have been received within expected receive period" do
      expect(agent).not_to be_working
      Agents::LiquidOutputAgent.async_receive agent.id, [events(:bob_website_agent_event).id]
      expect(agent.reload).to be_working
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(agent.reload).not_to be_working
    end
  end

  describe "validation" do
    before do
      expect(agent).to be_valid
    end

    it "should validate presence and length of secret" do
      agent.options[:secret] = ""
      expect(agent).not_to be_valid
      agent.options[:secret] = "foo"
      expect(agent).to be_valid
      agent.options[:secret] = "foo/bar"
      expect(agent).not_to be_valid
      agent.options[:secret] = "foo.xml"
      expect(agent).not_to be_valid
      agent.options[:secret] = false
      expect(agent).not_to be_valid
      agent.options[:secret] = []
      expect(agent).not_to be_valid
      agent.options[:secret] = ["foo.xml"]
      expect(agent).not_to be_valid
      agent.options[:secret] = ["hello", true]
      expect(agent).not_to be_valid
      agent.options[:secret] = ["hello"]
      expect(agent).not_to be_valid
      agent.options[:secret] = ["hello", "world"]
      expect(agent).not_to be_valid
    end

    it "should validate presence of expected_receive_period_in_days" do
      agent.options[:expected_receive_period_in_days] = ""
      expect(agent).not_to be_valid
      agent.options[:expected_receive_period_in_days] = 0
      expect(agent).not_to be_valid
      agent.options[:expected_receive_period_in_days] = -1
      expect(agent).not_to be_valid
    end

    it "should validate the event_limit" do
      agent.options[:event_limit] = ""
      expect(agent).to be_valid
      agent.options[:event_limit] = "1"
      expect(agent).to be_valid
      agent.options[:event_limit] = "1001"
      expect(agent).not_to be_valid
      agent.options[:event_limit] = "10000"
      expect(agent).not_to be_valid
    end

    it "should should not allow non-integer event limits" do
      agent.options[:event_limit] = "abc1234"
      expect(agent).not_to be_valid
    end
  end

  describe "#receive?" do

    let(:key)   { SecureRandom.uuid }
    let(:value) { SecureRandom.uuid }

    let(:incoming_events) do
      last_payload = { key => value }
      [Struct.new(:payload).new( { key => SecureRandom.uuid } ),
       Struct.new(:payload).new( { key => SecureRandom.uuid } ),
       Struct.new(:payload).new(last_payload)]
    end

    describe "and the mode is last event in" do

      before { agent.options['mode'] = 'Last event in' }

      it "stores the last event in memory" do
        agent.receive incoming_events
        expect(agent.memory['last_event'][key]).to equal(value)
      end

      describe "but the casing is wrong" do
        before { agent.options['mode'] = 'LAST EVENT IN' }

        it "stores the last event in memory" do
          agent.receive incoming_events
          expect(agent.memory['last_event'][key]).to equal(value)
        end
      end

    end

    describe "but the mode is merge" do

      let(:second_key)   { SecureRandom.uuid }
      let(:second_value) { SecureRandom.uuid }

      before { agent.options['mode'] = 'Merge events' }

      let(:incoming_events) do
        last_payload = { key => value }
        [Struct.new(:payload).new( { key => SecureRandom.uuid, second_key => second_value } ),
         Struct.new(:payload).new(last_payload)]
      end

      it "should merge all of the events passed to it" do
        agent.receive incoming_events
        expect(agent.memory['last_event'][key]).to equal(value)
        expect(agent.memory['last_event'][second_key]).to equal(second_value)
      end

      describe "but the casing on the mode is wrong" do

        before { agent.options['mode'] = 'MERGE EVENTS' }

        it "should merge all of the events passed to it" do
          agent.receive incoming_events
          expect(agent.memory['last_event'][key]).to equal(value)
          expect(agent.memory['last_event'][second_key]).to equal(second_value)
        end

      end

    end

    describe "but the mode is anything else" do

      before { agent.options['mode'] = SecureRandom.uuid }

      let(:incoming_events) do
        last_payload = { key => value }
        [Struct.new(:payload).new(last_payload)]
      end

      it "should do nothing" do
        agent.receive incoming_events
        expect(agent.memory.keys.count).to equal(0)
      end

    end

  end

  describe "#count_limit" do
    it "should have a default of 1000" do
      agent.options['event_limit'] = nil
      expect(agent.send(:count_limit)).to eq(1000)

      agent.options['event_limit'] = ''
      expect(agent.send(:count_limit)).to eq(1000)

      agent.options['event_limit'] = '  '
      expect(agent.send(:count_limit)).to eq(1000)
    end

    it "should convert string count limits to integers" do
      agent.options['event_limit'] = '1'
      expect(agent.send(:count_limit)).to eq(1)

      agent.options['event_limit'] = '2'
      expect(agent.send(:count_limit)).to eq(2)

      agent.options['event_limit'] = 3
      expect(agent.send(:count_limit)).to eq(3)
    end

    it "should default to 1000 with invalid values" do
      agent.options['event_limit'] = SecureRandom.uuid
      expect(agent.send(:count_limit)).to eq(1000)

      agent.options['event_limit'] = 'John Galt'
      expect(agent.send(:count_limit)).to eq(1000)
    end

    it "should not allow event limits above 1000" do
      agent.options['event_limit'] = '1001'
      expect(agent.send(:count_limit)).to eq(1000)

      agent.options['event_limit'] = '5000'
      expect(agent.send(:count_limit)).to eq(1000)
    end
  end

  describe "#receive_web_request?" do

    let(:secret) { SecureRandom.uuid }

    let(:params) { { 'secret' => secret } }

    let(:method) { nil }
    let(:format) { nil }

    let(:mime_type) { SecureRandom.uuid }
    let(:content) { "The key is {{#{key}}}." }

    let(:key)   { SecureRandom.uuid }
    let(:value) { SecureRandom.uuid }

    before do
      agent.options['secret'] = secret
      agent.options['mime_type'] = mime_type
      agent.options['content'] = content
      agent.memory['last_event'] = { key => value }
      agents(:bob_website_agent).events.destroy_all
    end

    it 'should respond with custom response header if configured with `response_headers` option' do
      agent.options['response_headers'] = {"X-My-Custom-Header" => 'hello'}
      result = agent.receive_web_request params, method, format
      expect(result).to eq(["The key is #{value}.", 200, mime_type, {"X-My-Custom-Header" => "hello"}])
    end

    it 'should allow the usage custom liquid tags' do
      agent.options['content'] = "{% credential aws_secret %}"
      result = agent.receive_web_request params, method, format
      expect(result).to eq(["1111111111-bob", 200, mime_type, nil])
    end

    describe "and the mode is last event in" do

      before { agent.options['mode'] = 'Last event in' }

      it "should render the results as a liquid template from the last event in" do
        result = agent.receive_web_request params, method, format

        expect(result[0]).to eq("The key is #{value}.")
        expect(result[1]).to eq(200)
        expect(result[2]).to eq(mime_type)
      end

      describe "but the casing is wrong" do
        before { agent.options['mode'] = 'last event in' }

        it "should render the results as a liquid template from the last event in" do
          result = agent.receive_web_request params, method, format

          expect(result[0]).to eq("The key is #{value}.")
          expect(result[1]).to eq(200)
          expect(result[2]).to eq(mime_type)
        end
      end

    end

    describe "and the mode is merge events" do

      before { agent.options['mode'] = 'Merge events' }

      it "should render the results as a liquid template from the last event in" do
        result = agent.receive_web_request params, method, format

        expect(result[0]).to eq("The key is #{value}.")
        expect(result[1]).to eq(200)
        expect(result[2]).to eq(mime_type)
      end

    end

    describe "and the mode is last X events" do

      before do
        agent.options['mode'] = 'Last X events'

        agents(:bob_website_agent).create_event payload: {
          "name" => "Dagny Taggart",
          "book" => "Atlas Shrugged"
        }
        agents(:bob_website_agent).create_event payload: {
          "name" => "John Galt",
          "book" => "Atlas Shrugged"
        }
        agents(:bob_website_agent).create_event payload: {
          "name" => "Howard Roark",
          "book" => "The Fountainhead"
        }

        agent.options['content'] = <<EOF
<table>
  {% for event in events %}
    <tr>
      <td>{{ event.name }}</td>
      <td>{{ event.book }}</td>
    </tr>
  {% endfor %}
</table>
EOF
      end

      it "should render the results as a liquid template from the last event in, limiting to 2" do
        agent.options['event_limit'] = 2
        result = agent.receive_web_request params, method, format

        expect(result[0]).to eq <<EOF
<table>
  
    <tr>
      <td>Howard Roark</td>
      <td>The Fountainhead</td>
    </tr>
  
    <tr>
      <td>John Galt</td>
      <td>Atlas Shrugged</td>
    </tr>
  
</table>
EOF
      end

      it "should render the results as a liquid template from the last event in, limiting to 1" do
        agent.options['event_limit'] = 1
        result = agent.receive_web_request params, method, format

        expect(result[0]).to eq <<EOF
<table>
  
    <tr>
      <td>Howard Roark</td>
      <td>The Fountainhead</td>
    </tr>
  
</table>
EOF
      end

      it "should render the results as a liquid template from the last event in, allowing no limit" do
        agent.options['event_limit'] = ''
        result = agent.receive_web_request params, method, format

        expect(result[0]).to eq <<EOF
<table>
  
    <tr>
      <td>Howard Roark</td>
      <td>The Fountainhead</td>
    </tr>
  
    <tr>
      <td>John Galt</td>
      <td>Atlas Shrugged</td>
    </tr>
  
    <tr>
      <td>Dagny Taggart</td>
      <td>Atlas Shrugged</td>
    </tr>
  
</table>
EOF
      end

      it "should allow the limiting by time, as well" do

        one_event = agent.received_events.select { |x| x.payload['name'] == 'John Galt' }.first
        one_event.created_at = 2.days.ago
        one_event.save!

        agent.options['event_limit'] = '1 day'
        result = agent.receive_web_request params, method, format

        expect(result[0]).to eq <<EOF
<table>
  
    <tr>
      <td>Howard Roark</td>
      <td>The Fountainhead</td>
    </tr>
  
    <tr>
      <td>Dagny Taggart</td>
      <td>Atlas Shrugged</td>
    </tr>
  
</table>
EOF
      end

      it "should not be case sensitive when limiting on time" do

        one_event = agent.received_events.select { |x| x.payload['name'] == 'John Galt' }.first
        one_event.created_at = 2.days.ago
        one_event.save!

        agent.options['event_limit'] = '1 DaY'
        result = agent.receive_web_request params, method, format

        expect(result[0]).to eq <<EOF
<table>
  
    <tr>
      <td>Howard Roark</td>
      <td>The Fountainhead</td>
    </tr>
  
    <tr>
      <td>Dagny Taggart</td>
      <td>Atlas Shrugged</td>
    </tr>
  
</table>
EOF
      end

      it "it should continue to work when the event limit is wrong" do
        agent.options['event_limit'] = 'five days'
        result = agent.receive_web_request params, method, format

        expect(result[0].include?("Howard Roark")).to eq(true)
        expect(result[0].include?("Dagny Taggart")).to eq(true)
        expect(result[0].include?("John Galt")).to eq(true)

        agent.options['event_limit'] = '5 quibblequarks'
        result = agent.receive_web_request params, method, format

        expect(result[0].include?("Howard Roark")).to eq(true)
        expect(result[0].include?("Dagny Taggart")).to eq(true)
        expect(result[0].include?("John Galt")).to eq(true)
      end

      describe "but the mode was set to last X events with the wrong casing" do

        before { agent.options['mode'] = 'LAST X EVENTS' }

        it "should still work as last x events" do
          result = agent.receive_web_request params, method, format
          expect(result[0].include?("Howard Roark")).to eq(true)
          expect(result[0].include?("Dagny Taggart")).to eq(true)
          expect(result[0].include?("John Galt")).to eq(true)
        end

      end

    end

    describe "but the secret provided does not match" do
      before { params['secret'] = SecureRandom.uuid }

      it "should return a 401 response" do
        result = agent.receive_web_request params, method, format

        expect(result[0]).to eq("Not Authorized")
        expect(result[1]).to eq(401)
      end

      it "should return a 401 json response if the format is json" do
        result = agent.receive_web_request params, method, 'json'

        expect(result[0][:error]).to eq("Not Authorized")
        expect(result[1]).to eq(401)
      end
    end
  end
end
