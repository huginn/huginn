require 'rails_helper'

describe Agents::DelayAgent do
  let(:agent) do
    _agent = Agents::DelayAgent.new(name: 'My DelayAgent')
    _agent.options = _agent.default_options.merge('max_events' => 2)
    _agent.user = users(:bob)
    _agent.sources << agents(:bob_website_agent)
    _agent.save!
    _agent
  end

  def create_event
    _event = Event.new(payload: { random: rand })
    _event.agent = agents(:bob_website_agent)
    _event.save!
    _event
  end

  let(:first_event) { create_event }
  let(:second_event) { create_event }
  let(:third_event) { create_event }

  describe "#working?" do
    it "checks if events have been received within expected receive period" do
      expect(agent).not_to be_working
      Agents::DelayAgent.async_receive agent.id, [events(:bob_website_agent_event).id]
      expect(agent.reload).to be_working
      the_future = (agent.options[:expected_receive_period_in_days].to_i + 1).days.from_now
      stub(Time).now { the_future }
      expect(agent.reload).not_to be_working
    end
  end

  describe "validation" do
    before do
      expect(agent).to be_valid
    end

    it "should validate max_events" do
      agent.options.delete('max_events')
      expect(agent).not_to be_valid
      agent.options['max_events'] = ""
      expect(agent).not_to be_valid
      agent.options['max_events'] = "0"
      expect(agent).not_to be_valid
      agent.options['max_events'] = "10"
      expect(agent).to be_valid
    end

    it "should validate presence of expected_receive_period_in_days" do
      agent.options['expected_receive_period_in_days'] = ""
      expect(agent).not_to be_valid
      agent.options['expected_receive_period_in_days'] = 0
      expect(agent).not_to be_valid
      agent.options['expected_receive_period_in_days'] = -1
      expect(agent).not_to be_valid
    end

    it "should validate keep" do
      agent.options.delete('keep')
      expect(agent).not_to be_valid
      agent.options['keep'] = ""
      expect(agent).not_to be_valid
      agent.options['keep'] = 'wrong'
      expect(agent).not_to be_valid
      agent.options['keep'] = 'newest'
      expect(agent).to be_valid
      agent.options['keep'] = 'oldest'
      expect(agent).to be_valid
    end
  end

  describe "#receive" do
    it "records Events" do
      expect(agent.memory).to be_empty
      agent.receive([first_event])
      expect(agent.memory).not_to be_empty
      agent.receive([second_event])
      expect(agent.memory['event_ids']).to eq [first_event.id, second_event.id]
    end

    it "keeps the newest when 'keep' is set to 'newest'" do
      expect(agent.options['keep']).to eq 'newest'
      agent.receive([first_event, second_event, third_event])
      expect(agent.memory['event_ids']).to eq [second_event.id, third_event.id]
    end

    it "keeps the oldest when 'keep' is set to 'oldest'" do
      agent.options['keep'] = 'oldest'
      agent.receive([first_event, second_event, third_event])
      expect(agent.memory['event_ids']).to eq [first_event.id, second_event.id]
    end
  end

  describe "#check" do
    it "re-emits Events and clears the memory" do
      agent.receive([first_event, second_event, third_event])
      expect(agent.memory['event_ids']).to eq [second_event.id, third_event.id]

      expect {
        agent.check
      }.to change { agent.events.count }.by(2)

      events = agent.events.reorder('events.id desc')
      expect(events.first.payload).to eq third_event.payload
      expect(events.second.payload).to eq second_event.payload

      expect(agent.memory['event_ids']).to eq []
    end

    it "re-emits max_emitted_events and clears just them from the memory" do
      agent.options['max_emitted_events'] = 1
      agent.receive([first_event, second_event, third_event])
      expect(agent.memory['event_ids']).to eq [second_event.id, third_event.id]

      expect {
        agent.check
      }.to change { agent.events.count }.by(1)

      events = agent.events.reorder('events.id desc')
      expect(agent.memory['event_ids']).to eq [third_event.id]
      expect(events.first.payload).to eq second_event.payload

    end
  end
end
