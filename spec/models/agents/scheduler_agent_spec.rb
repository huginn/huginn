require 'spec_helper'

describe Agents::SchedulerAgent do
  before do
    @agent = Agents::SchedulerAgent.new(name: 'Example', options: { 'schedule' => '0 * * * *' })
    @agent.user = users(:bob)
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

      @agent.options['schedule'] = '*/15 * * * * *'
      @agent.should be_valid

      @agent.options['schedule'] = '*/1 * * * *'
      @agent.should be_valid

      @agent.options['schedule'] = '*/1 * * *'
      @agent.should_not be_valid
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
