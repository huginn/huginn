require 'spec_helper'

describe Agents::SchedulerAgent do
  before do
    @agent = Agents::SchedulerAgent.new(name: 'Example', options: { 'schedule' => '0 * * * *' })
    @agent.user = users(:bob)
    @agent.save
  end

  describe "validation" do
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
      @agent.options['schedule'] = '*/15 * * * * *'
      @agent.should_not be_valid

      @agent.options['schedule'] = '0 * * * * *'
      @agent.should be_valid
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
    it "should run targets" do
      targets = [agents(:bob_website_agent), agents(:bob_weather_agent)]
      @agent.targets = targets
      @agent.save!

      target_ids = targets.map(&:id)
      stub(Agent).async_check(anything) { |id|
        target_ids.delete(id)
      }

      @agent.check!
      target_ids.should be_empty
    end
  end
end
