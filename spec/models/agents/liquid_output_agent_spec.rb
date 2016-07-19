# encoding: utf-8

require 'rails_helper'

describe Agents::LiquidOutputAgent do
  let(:agent) do
    _agent = Agents::LiquidOutputAgent.new(:name => 'My Data Output Agent')
    _agent.options = _agent.default_options.merge('secrets' => ['secret1', 'secret2'], 'events_to_show' => 3)
    _agent.options['secrets'] = "a secret"
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

    it "should validate presence and length of secrets" do
      agent.options[:secrets] = ""
      expect(agent).not_to be_valid
      agent.options[:secrets] = "foo"
      expect(agent).to be_valid
      agent.options[:secrets] = "foo/bar"
      expect(agent).not_to be_valid
      agent.options[:secrets] = "foo.xml"
      expect(agent).not_to be_valid
      agent.options[:secrets] = false
      expect(agent).not_to be_valid
      agent.options[:secrets] = []
      expect(agent).not_to be_valid
      agent.options[:secrets] = ["foo.xml"]
      expect(agent).not_to be_valid
      agent.options[:secrets] = ["hello", true]
      expect(agent).not_to be_valid
      agent.options[:secrets] = ["hello"]
      expect(agent).not_to be_valid
      agent.options[:secrets] = ["hello", "world"]
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

    it "stores the last event in memory" do
      agent.receive incoming_events
      expect(agent.memory['last_event'][key]).to equal(value)
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
    end

  end

  describe "#receive_web_request?" do

    let(:secrets) { SecureRandom.uuid }

    let(:params) { { 'secret' => secrets } }

    let(:method) { nil }
    let(:format) { nil }

    let(:mime_type) { SecureRandom.uuid }
    let(:content) { "The key is {{#{key}}}." }

    let(:key)   { SecureRandom.uuid }
    let(:value) { SecureRandom.uuid }

    before do
      agent.options['secrets'] = secrets
      agent.options['mime_type'] = mime_type
      agent.options['content'] = content
      agent.memory['last_event'] = { key => value }
    end

    it "render the results as a liquid template" do
      result = agent.receive_web_request params, method, format

      expect(result[0]).to eq("The key is #{value}.")
      expect(result[1]).to eq(200)
      expect(result[2]).to eq(mime_type)
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
