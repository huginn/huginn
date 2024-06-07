require 'rails_helper'

describe Agents::ArchivedAgent do
  let(:agent_id) {
    agent = agents(:jane_website_agent)
    agent.sources << agents(:jane_weather_agent)
    agent.id
  }

  let(:agent) {
    Agent.where(id: agent_id).archive_all!
    Agent.find(agent_id)
  }

  def create_event(payload)
    agents(:jane_weather_agent).events.create!(payload:)
  end

  describe '.should_run?' do
    it 'is false' do
      expect(Agents::ArchivedAgent.should_run?).to eq false
    end
  end

  describe '.can_control_other_agents?' do
    it 'is true' do
      expect(Agents::ArchivedAgent.can_control_other_agents?).to eq true
    end
  end

  describe 'control_action' do
    it 'is set' do
      expect(agent.control_action).to eq 'control'
    end
  end

  describe 'validation' do
    before do
      expect(agent).to be_valid
    end

    it 'cannot be enabled' do
      agent.disabled = false
      expect(agent).not_to be_valid
    end

    it 'cannot change its options' do
      agent.options[:foo] = true
      expect(agent).not_to be_valid
    end
  end

  describe '#check' do
    it 'does not cause error' do
      expect {
        agent.check
      }.not_to raise_error
    end
  end

  describe '#receive' do
    let(:event) { create_event({ name: 'foo', numbers: [1, 2, 3, 4] }) }

    it 'does not cause error' do
      expect {
        agent.receive([event])
      }.not_to raise_error
    end
  end
end
