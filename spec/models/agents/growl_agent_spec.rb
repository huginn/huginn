require 'spec_helper'

describe Agents::GrowlAgent do
  before do
    @checker = Agents::GrowlAgent.new(:name => 'a growl agent',
                                      :options => { :growlserver => 'localhost',
                                                    :growlappname => 'HuginnGrowlApp',
                                                    :growlnotificationname => 'Notification',
                                                    :expected_receive_period_in_days => '1' })
    @checker.user = users(:bob)
    @checker.save!
    
    class Agents::GrowlAgent #this should really be done with RSpec-Mocks
      def notify_growl(message,subject)
      end
    end

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :subject => 'Weather Alert!', :message => 'Looks like its going to rain' }
    @event.save!
  end

  describe "#working?" do
    it "checks if events have been received within the expected receive period" do
      @checker.should_not be_working # No events received
      Agents::GrowlAgent.async_receive @checker.id, [@event.id]
      @checker.reload.should be_working # Just received events
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      @checker.reload.should_not be_working # More time has passed than the expected receive period without any new events
    end
  end

  describe "validation" do
    before do
      @checker.should be_valid
    end

    it "should validate presence of of growlserver" do
      @checker.options[:growlserver] = ""
      @checker.should_not be_valid
    end

    it "should validate presence of expected_receive_period_in_days" do
      @checker.options[:expected_receive_period_in_days] = ""
      @checker.should_not be_valid
    end
  end
end