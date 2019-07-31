require 'rails_helper'

describe AgentReemitJob do
  subject { described_class.new }
  let(:agent) { agents(:bob_website_agent) }
  let(:agent_event) { events(:bob_website_agent_event) }

  it "re-emits all events created by the given Agent" do
    2.times { agent_event.dup.save! }

    expect {
      subject.perform(agent, agent.most_recent_event.id)
    }.to change(Event, :count).by(3)

    last_event = Event.last
    expect(last_event.user).to eq(agent_event.user)
    expect(last_event.agent).to eq(agent_event.agent)
    expect(last_event.payload).to eq(agent_event.payload)
  end

  it "doesn't re-emit events created after the the most_recent_event_id" do
    2.times { agent_event.dup.save! }

    # create one more
    most_recent_event = agent.most_recent_event.id
    agent_event.dup.save!

    expect {
      subject.perform(agent, most_recent_event, false)
    }.to change(Event, :count).by(3)

    last_event = Event.last
    expect(last_event.user).to eq(agent_event.user)
    expect(last_event.agent).to eq(agent_event.agent)
    expect(last_event.payload).to eq(agent_event.payload)
  end

  context "when delete_old_events set to true" do
    it "re-emits all events created by the given Agent and destroys originals" do
      original_events = [agent_event]
      2.times do
        original_events << agent_event.dup.tap{ |e| e.save! }
      end

      expect {
        subject.perform(agent, agent.most_recent_event.id, true)
      }.to change(Event, :count).by(0)

      original_events.each { |e| expect(e.destroyed?) }

      last_event = Event.last
      expect(last_event.user).to eq(agent_event.user)
      expect(last_event.agent).to eq(agent_event.agent)
      expect(last_event.payload).to eq(agent_event.payload)
    end
  end
end
