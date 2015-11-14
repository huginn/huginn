require 'rails_helper'

describe Agents::SchedulerAgent do
  let(:valid_params) {
    {
      name: 'Example',
      options: {
        'action' => 'run',
        'schedule' => '0 * * * *'
      },
    }
  }

  let(:agent) {
    described_class.create!(valid_params) { |agent|
      agent.user = users(:bob)
    }
  }

  it_behaves_like AgentControllerConcern

  describe "validation" do
    it "should validate schedule" do
      expect(agent).to be_valid

      agent.options.delete('schedule')
      expect(agent).not_to be_valid

      agent.options['schedule'] = nil
      expect(agent).not_to be_valid

      agent.options['schedule'] = ''
      expect(agent).not_to be_valid

      agent.options['schedule'] = '0'
      expect(agent).not_to be_valid

      agent.options['schedule'] = '*/15 * * * * * *'
      expect(agent).not_to be_valid

      agent.options['schedule'] = '*/1 * * * *'
      expect(agent).to be_valid

      agent.options['schedule'] = '*/1 * * *'
      expect(agent).not_to be_valid

      stub(agent).second_precision_enabled { true }
      agent.options['schedule'] = '*/15 * * * * *'
      expect(agent).to be_valid

      stub(agent).second_precision_enabled { false }
      agent.options['schedule'] = '*/10 * * * * *'
      expect(agent).not_to be_valid

      agent.options['schedule'] = '5/30 * * * * *'
      expect(agent).not_to be_valid

      agent.options['schedule'] = '*/15 * * * * *'
      expect(agent).to be_valid

      agent.options['schedule'] = '15,45 * * * * *'
      expect(agent).to be_valid

      agent.options['schedule'] = '0 * * * * *'
      expect(agent).to be_valid
    end
  end

  describe "save" do
    it "should delete memory['scheduled_at'] if and only if options is changed" do
      time = Time.now.to_i

      agent.memory['scheduled_at'] = time
      agent.save
      expect(agent.memory['scheduled_at']).to eq(time)

      agent.memory['scheduled_at'] = time
      # Currently agent.options[]= is not detected
      agent.options = {
        'action' => 'run',
        'schedule' => '*/5 * * * *'
      }
      agent.save
      expect(agent.memory['scheduled_at']).to be_nil
    end
  end
end
