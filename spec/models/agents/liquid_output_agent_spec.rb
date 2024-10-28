# encoding: utf-8

require 'rails_helper'

describe Agents::LiquidOutputAgent do
  let(:agent) do
    _agent = Agents::LiquidOutputAgent.new(name: 'My Data Output Agent')
    _agent.options = _agent.default_options.merge(
      'secret' => 'a secret1',
      'events_to_show' => 3,
    )
    _agent.user = users(:bob)
    _agent.sources << agents(:bob_website_agent)
    _agent.save!
    _agent
  end

  let(:event_struct) { Struct.new(:payload) }

  describe "#working?" do
    it "checks if events have been received within expected receive period" do
      expect(agent).not_to be_working
      Agents::LiquidOutputAgent.async_receive agent.id, [events(:bob_website_agent_event).id]
      expect(agent.reload).to be_working
      two_days_from_now = 2.days.from_now
      allow(Time).to receive(:now) { two_days_from_now }
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

    it "should validate the event_limit with relative time" do
      agent.options[:event_limit] = "15 minutes"
      expect(agent).to be_valid
      agent.options[:event_limit] = "1 century"
      expect(agent).not_to be_valid
    end

    it "should not allow non-integer event limits" do
      agent.options[:event_limit] = "abc1234"
      expect(agent).not_to be_valid
    end
  end

  describe "#receive?" do
    let(:key)   { SecureRandom.uuid }
    let(:value) { SecureRandom.uuid }

    let(:incoming_events) do
      last_payload = { key => value }
      [event_struct.new( { key => SecureRandom.uuid } ),
       event_struct.new( { key => SecureRandom.uuid } ),
       event_struct.new(last_payload)]
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
        [event_struct.new( { key => SecureRandom.uuid, second_key => second_value } ),
         event_struct.new(last_payload)]
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
        [event_struct.new(last_payload)]
      end

      it "should update nothing" do
        expect {
          agent.receive incoming_events
        }.not_to change { agent.reload.memory&.fetch("last_event", nil) }
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

  describe "#receive_web_request" do
    let(:secret) { SecureRandom.uuid }

    let(:headers) { {} }
    let(:params) { { 'secret' => secret } }
    let(:format) { :html }
    let(:request) {
      instance_double(
        ActionDispatch::Request,
        headers:,
        params:,
        format:,
      )
    }

    let(:mime_type) { SecureRandom.uuid }
    let(:content) { "The key is {{#{key}}}." }

    let(:key)   { SecureRandom.uuid }
    let(:value) { SecureRandom.uuid }

    before do
      agent.options['secret'] = secret
      agent.options['mime_type'] = mime_type
      agent.options['content'] = content
      agent.memory['last_event'] = { key => value }
      agent.save!
      agents(:bob_website_agent).events.destroy_all
    end

    it "should output LF-terminated lines if line_break_is_lf is true" do
      agent.options["content"] = "hello\r\nworld\r\n"

      result = agent.receive_web_request request
      expect(result[0]).to eq "hello\r\nworld\r\n"

      agent.options["line_break_is_lf"] = "true"
      result = agent.receive_web_request request
      expect(result[0]).to eq "hello\nworld\n"

      agent.options["line_break_is_lf"] = "false"
      result = agent.receive_web_request request
      expect(result[0]).to eq "hello\r\nworld\r\n"
    end

    it 'should respond with custom response header if configured with `response_headers` option' do
      agent.options['response_headers'] = { "X-My-Custom-Header" => 'hello' }
      result = agent.receive_web_request request
      expect(result).to match([
        "The key is #{value}.",
        200,
        mime_type,
        a_hash_including(
          "Cache-Control" => a_kind_of(String),
          "ETag" => a_kind_of(String),
          "Last-Modified" => a_kind_of(String),
          "X-My-Custom-Header" => "hello"
        )
      ])
    end

    it 'should allow the usage custom liquid tags' do
      agent.options['content'] = "{% credential aws_secret %}"
      result = agent.receive_web_request request
      expect(result).to match([
        "1111111111-bob",
        200,
        mime_type,
        a_hash_including(
          "Cache-Control" => a_kind_of(String),
          "ETag" => a_kind_of(String),
          "Last-Modified" => a_kind_of(String),
        )
      ])
    end

    describe "when requested with or without the If-None-Match header" do
      let(:now) { Time.now }

      it "should conditionally return 304 responses whenever ETag matches" do
        travel_to now

        allow(agent).to receive(:liquified_content).and_call_original

        result = agent.receive_web_request request
        expect(result).to eq([
          "The key is #{value}.",
          200,
          mime_type,
          {
            'Cache-Control' => "max-age=#{agent.options['expected_receive_period_in_days'].to_i * 86400}",
            'ETag' => agent.etag,
            'Last-Modified' => agent.memory['last_modified_at'].to_time.httpdate,
          }
        ])
        expect(agent).to have_received(:liquified_content).once

        travel_to now + 1
        request.headers['If-None-Match'] = agent.etag
        result = agent.receive_web_request request
        expect(result).to eq([nil, 304, {}])
        expect(agent).to have_received(:liquified_content).once

        # Receiving an event will update the ETag and Last-Modified-At
        event = agents(:bob_website_agent).events.create!(payload: { key => 'latest' })
        AgentReceiveJob.perform_now agent.id, [event.id]
        agent.reload

        travel_to now + 2
        result = agent.receive_web_request request
        expect(result).to eq(["The key is latest.", 200, mime_type, {
          'Cache-Control' => "max-age=#{agent.options['expected_receive_period_in_days'].to_i * 86400}",
          'ETag' => agent.etag,
          'Last-Modified' => agent.last_receive_at.httpdate,
        }])
        expect(agent).to have_received(:liquified_content).twice

        travel_to now + 3
        request.headers['If-None-Match'] = agent.etag
        result = agent.receive_web_request request
        expect(result).to eq([nil, 304, {}])
        expect(agent).to have_received(:liquified_content).twice

        # Changing options will update the ETag and Last-Modified-At
        agent.update!(options: agent.options.merge('content' => "The key is now {{#{key}}}."))
        agent.reload

        result = agent.receive_web_request request
        expect(result).to eq(["The key is now latest.", 200, mime_type, {
          'Cache-Control' => "max-age=#{agent.options['expected_receive_period_in_days'].to_i * 86400}",
          'ETag' => agent.etag,
          'Last-Modified' => (now + 3).httpdate,
        }])
        expect(agent).to have_received(:liquified_content).exactly(3).times
      end
    end

    describe "and the mode is last event in" do
      before { agent.options['mode'] = 'Last event in' }

      it "should render the results as a liquid template from the last event in" do
        result = agent.receive_web_request request

        expect(result[0]).to eq("The key is #{value}.")
        expect(result[1]).to eq(200)
        expect(result[2]).to eq(mime_type)
      end

      describe "but the casing is wrong" do
        before { agent.options['mode'] = 'last event in' }

        it "should render the results as a liquid template from the last event in" do
          result = agent.receive_web_request request

          expect(result).to match(["The key is #{value}.", 200, mime_type, a_kind_of(Hash)])
        end
      end
    end

    describe "and the mode is merge events" do
      before { agent.options['mode'] = 'Merge events' }

      it "should render the results as a liquid template from the last event in" do
        result = agent.receive_web_request request

        expect(result).to match(["The key is #{value}.", 200, mime_type, a_kind_of(Hash)])
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
        result = agent.receive_web_request request

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
        result = agent.receive_web_request request

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
        result = agent.receive_web_request request

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
        result = agent.receive_web_request request

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
        result = agent.receive_web_request request

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
        result = agent.receive_web_request request

        expect(result[0]).to include("Howard Roark")
        expect(result[0]).to include("Dagny Taggart")
        expect(result[0]).to include("John Galt")

        agent.options['event_limit'] = '5 quibblequarks'
        result = agent.receive_web_request request

        expect(result[0]).to include("Howard Roark")
        expect(result[0]).to include("Dagny Taggart")
        expect(result[0]).to include("John Galt")
      end

      describe "but the mode was set to last X events with the wrong casing" do
        before { agent.options['mode'] = 'LAST X EVENTS' }

        it "should still work as last x events" do
          result = agent.receive_web_request request
          expect(result[0]).to include("Howard Roark")
          expect(result[0]).to include("Dagny Taggart")
          expect(result[0]).to include("John Galt")
        end
      end
    end

    describe "but the secret provided does not match" do
      before { params['secret'] = SecureRandom.uuid }

      it "should return a 401 response" do
        result = agent.receive_web_request request

        expect(result[0]).to eq("Not Authorized")
        expect(result[1]).to eq(401)
      end

      context 'if the format is json' do
        let(:format) { :json }

        it "should return a 401 json response " do
          result = agent.receive_web_request request

          expect(result[0][:error]).to eq("Not Authorized")
          expect(result[1]).to eq(401)
        end
      end
    end
  end
end
