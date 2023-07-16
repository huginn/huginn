require 'rails_helper'

describe Agents::DelayAgent do
  let(:agent) {
    Agents::DelayAgent.create!(
      name: 'My DelayAgent',
      user: users(:bob),
      options: default_options.merge('max_events' => 2),
      sources: [agents(:bob_website_agent)]
    )
  }

  let(:default_options) { Agents::DelayAgent.new.default_options }

  def create_event(value)
    Event.create!(payload: { value: }, agent: agents(:bob_website_agent))
  end

  let(:first_event) { create_event("one") }
  let(:second_event) { create_event("two") }
  let(:third_event) { create_event("three") }

  describe "#working?" do
    it "checks if events have been received within expected receive period" do
      expect(agent).not_to be_working
      Agents::DelayAgent.async_receive agent.id, [events(:bob_website_agent_event).id]
      expect(agent.reload).to be_working
      the_future = (agent.options[:expected_receive_period_in_days].to_i + 1).days.from_now
      allow(Time).to receive(:now) { the_future }
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

    it "should validate emit_interval" do
      agent.options.delete('emit_interval')
      expect(agent).to be_valid
      agent.options['emit_interval'] = "0"
      expect(agent).to be_valid
      agent.options['emit_interval'] = "0.5"
      expect(agent).to be_valid
      agent.options['emit_interval'] = 0.5
      expect(agent).to be_valid
      agent.options['emit_interval'] = ''
      expect(agent).not_to be_valid
      agent.options['emit_interval'] = nil
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

      expect(agent).to receive(:sleep).with(0).once

      expect {
        agent.check
      }.to change { agent.events.count }.by(2)

      events = agent.events.reorder(id: :desc)
      expect(events.first.payload).to eq third_event.payload
      expect(events.second.payload).to eq second_event.payload

      expect(agent.memory['event_ids']).to eq []
    end

    context "with events_order and emit_interval" do
      before do
        agent.update!(options: agent.options.merge(
          'events_order' => ['{{ value }}'],
          'emit_interval' => 1,
        ))
      end

      it "re-emits Events in that order and clears the memory with that interval" do
        agent.receive([first_event, second_event, third_event])
        expect(agent.memory['event_ids']).to eq [second_event.id, third_event.id]

        expect(agent).to receive(:sleep).with(1).once

        expect {
          agent.check
        }.to change { agent.events.count }.by(2)

        events = agent.events.reorder(id: :desc)
        expect(events.first.payload).to eq second_event.payload
        expect(events.second.payload).to eq third_event.payload

        expect(agent.memory['event_ids']).to eq []
      end
    end

    context "with max_emitted_events" do
      before do
        agent.update!(options: agent.options.merge('max_emitted_events' => 1))
      end

      it "re-emits max_emitted_events and clears just them from the memory" do
        agent.receive([first_event, second_event, third_event])
        expect(agent.memory['event_ids']).to eq [second_event.id, third_event.id]

        expect {
          agent.check
        }.to change { agent.events.count }.by(1)

        events = agent.events.reorder(id: :desc)
        expect(agent.memory['event_ids']).to eq [third_event.id]
        expect(events.first.payload).to eq second_event.payload
      end
    end
  end
end
