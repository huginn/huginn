require 'spec_helper'

shared_examples_for AgentControllerConcern do
  describe "preconditions" do
    it "must be satisfied for these shared examples" do
      expect(agent.user).to eq(users(:bob))
      expect(agent.control_action).to eq('run')
    end
  end

  describe "validation" do
    it "should validate action" do
      ['run', 'enable', 'disable'].each { |action|
        agent.options['action'] = action
        expect(agent).to be_valid
      }

      ['delete', '', nil, 1, true].each { |action|
        agent.options['action'] = action
        expect(agent).not_to be_valid
      }
    end
  end

  describe 'control_action' do
    it "cannot be 'run' if any of the control targets cannot be scheduled" do
      expect(agent.control_action).to eq('run')
      agent.control_targets = [agents(:bob_rain_notifier_agent)]
      expect(agent).not_to be_valid
    end

    it "can be 'enable' or 'disable' no matter if control targets can be scheduled or not" do
      ['enable', 'disable'].each { |action|
        agent.options['action'] = action
        agent.control_targets = [agents(:bob_rain_notifier_agent)]
        expect(agent).to be_valid
      }
    end
  end

  describe "control!" do
    before do
      agent.control_targets = [agents(:bob_website_agent), agents(:bob_weather_agent)]
      agent.save!
    end

    it "should run targets" do
      control_target_ids = agent.control_targets.map(&:id)
      stub(Agent).async_check(anything) { |id|
        control_target_ids.delete(id)
      }

      agent.control!
      expect(control_target_ids).to be_empty
    end

    it "should not run disabled targets" do
      control_target_ids = agent.control_targets.map(&:id)
      stub(Agent).async_check(anything) { |id|
        control_target_ids.delete(id)
      }

      agent.control_targets.last.update!(disabled: true)

      agent.control!
      expect(control_target_ids).to eq [agent.control_targets.last.id]
    end

    it "should enable targets" do
      agent.options['action'] = 'disable'
      agent.save!
      agent.control_targets.first.update!(disabled: true)

      agent.control!
      expect(agent.control_targets.reload).to all(be_disabled)
    end

    it "should disable targets" do
      agent.options['action'] = 'enable'
      agent.save!
      agent.control_targets.first.update!(disabled: true)

      agent.control!
      expect(agent.control_targets.reload).to all(satisfy { |a| !a.disabled? })
    end
  end
end
