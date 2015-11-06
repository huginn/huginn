require 'rails_helper'

shared_examples_for AgentControllerConcern do
  describe "preconditions" do
    it "must be satisfied for these shared examples" do
      expect(agent.user).to eq(users(:bob))
      expect(agent.control_action).to eq('run')
    end
  end

  describe "validation" do
    describe "of action" do
      it "should allow certain values" do
        ['run', 'enable', 'disable', '{{ action }}'].each { |action|
          agent.options['action'] = action
          expect(agent).to be_valid
        }
      end

      it "should disallow obviously bad values" do
        ['delete', nil, 1, true].each { |action|
          agent.options['action'] = action
          expect(agent).not_to be_valid
        }
      end

      it "should accept 'run' if all target agents are schedulable" do
        agent.control_targets = [agents(:bob_website_agent)]
        expect(agent).to be_valid
      end

      it "should reject 'run' if targets include an unschedulable agent" do
        agent.control_targets = [agents(:bob_rain_notifier_agent)]
        expect(agent).not_to be_valid
      end

      it "should not reject 'enable' or 'disable' no matter if targets include an unschedulable agent" do
        ['enable', 'disable'].each { |action|
          agent.options['action'] = action
          agent.control_targets = [agents(:bob_rain_notifier_agent)]
          expect(agent).to be_valid
        }
      end

      it "should ensure that 'configure_options' exists in options when the action is 'configure'" do
        agent.options['action'] = 'configure'
        expect(agent).not_to be_valid
        agent.options['configure_options'] = {}
        expect(agent).not_to be_valid
        agent.options['configure_options'] = { 'key' => 'value' }
        expect(agent).to be_valid
      end
    end
  end

  describe 'control_action' do
    it "returns options['action']" do
      expect(agent.control_action).to eq('run')

      ['run', 'enable', 'disable'].each { |action|
        agent.options['action'] = action
        expect(agent.control_action).to eq(action)
      }
    end

    it "returns the result of interpolation" do
      expect(agent.control_action).to eq('run')

      agent.options['action'] = '{{ "enable" }}'
      expect(agent.control_action).to eq('enable')
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

    it "should configure targets" do
      agent.options['action'] = 'configure'
      agent.options['configure_options'] = { 'url' => 'http://some-new-url.com/{{"something" | upcase}}' }
      agent.save!
      old_options = agents(:bob_website_agent).options

      agent.control!

      expect(agent.control_targets.reload).to all(satisfy { |a| a.options['url'] == 'http://some-new-url.com/SOMETHING' })
      expect(agents(:bob_website_agent).reload.options).to eq(old_options.merge('url' => 'http://some-new-url.com/SOMETHING'))
    end

    it "should configure targets with nested objects" do
      agent.control_targets << agents(:bob_data_output_agent)
      agent.options['action'] = 'configure'
      agent.options['configure_options'] = { 
        template: {
          item: {
           title: "changed"
          }
        }
      }
      agent.save!
      old_options = agents(:bob_data_output_agent).options

      agent.control!

      expect(agent.control_targets.reload).to all(satisfy { |a| a.options['template'] && a.options['template']['item'] && (a.options['template']['item']['title'] == 'changed') })
      expect(agents(:bob_data_output_agent).reload.options).to eq(old_options.deep_merge(agent.options['configure_options']))
    end
  end
end
