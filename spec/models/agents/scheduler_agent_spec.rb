require 'spec_helper'

describe Agents::SchedulerAgent do
  before do
    @agent = Agents::SchedulerAgent.new(name: 'Example', options: { 'schedule' => '0 * * * *' })
    @agent.user = users(:bob)
    @agent.save
  end

  describe "validation" do
    it "should validate action" do
      ['run', 'enable', 'disable', '', nil].each { |action|
        @agent.options['action'] = action
        @agent.should be_valid
      }

      ['delete', 1, true].each { |action|
        @agent.options['action'] = action
        @agent.should_not be_valid
      }
    end

    it "should validate schedule" do
      @agent.should be_valid

      @agent.options.delete('schedule')
      @agent.should_not be_valid

      @agent.options['schedule'] = nil
      @agent.should_not be_valid

      @agent.options['schedule'] = ''
      @agent.should_not be_valid

      @agent.options['schedule'] = '0'
      @agent.should_not be_valid

      @agent.options['schedule'] = '*/15 * * * * * *'
      @agent.should_not be_valid

      @agent.options['schedule'] = '*/1 * * * *'
      @agent.should be_valid

      @agent.options['schedule'] = '*/1 * * *'
      @agent.should_not be_valid

      stub(@agent).second_precision_enabled { true }
      @agent.options['schedule'] = '*/15 * * * * *'
      @agent.should be_valid

      stub(@agent).second_precision_enabled { false }
      @agent.options['schedule'] = '*/10 * * * * *'
      @agent.should_not be_valid

      @agent.options['schedule'] = '5/30 * * * * *'
      @agent.should_not be_valid

      @agent.options['schedule'] = '*/15 * * * * *'
      @agent.should be_valid

      @agent.options['schedule'] = '15,45 * * * * *'
      @agent.should be_valid

      @agent.options['schedule'] = '0 * * * * *'
      @agent.should be_valid
    end
  end

  describe 'control_action' do
    it "should be one of the supported values" do
      ['run', '', nil].each { |action|
        @agent.options['action'] = action
        @agent.control_action.should == 'run'
      }

      ['enable', 'disable'].each { |action|
        @agent.options['action'] = action
        @agent.control_action.should == action
      }
    end
  end

  describe "save" do
    it "should delete memory['scheduled_at'] if and only if options is changed" do
      time = Time.now.to_i

      @agent.memory['scheduled_at'] = time
      @agent.save
      @agent.memory['scheduled_at'].should == time

      @agent.memory['scheduled_at'] = time
      # Currently @agent.options[]= is not detected
      @agent.options = { 'schedule' => '*/5 * * * *' }
      @agent.save
      @agent.memory['scheduled_at'].should be_nil
    end
  end

  describe "check!" do
    it "should control targets" do
      control_targets = [agents(:bob_website_agent), agents(:bob_weather_agent)]
      @agent.control_targets = control_targets
      @agent.save!

      control_target_ids = control_targets.map(&:id)
      stub(Agent).async_check(anything) { |id|
        control_target_ids.delete(id)
      }

      @agent.check!
      control_target_ids.should be_empty

      @agent.options['action'] = 'disable'
      @agent.save!

      @agent.check!
      control_targets.all? { |control_target| control_target.disabled? }

      @agent.options['action'] = 'enable'
      @agent.save!

      @agent.check!
      control_targets.all? { |control_target| !control_target.disabled? }
    end
  end
end
