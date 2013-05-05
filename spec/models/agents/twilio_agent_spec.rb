require 'spec_helper'

describe Agents::TwilioAgent do
    before do
        @checker = Agents::TwilioAgent.new(:name => "somename", :options => {:account_sid => "x",:auth_token => "x",:senderscell => "x", :receiverscell => "x", :expected_receive_period_in_days => "x"})
        @checker.user = users(:bob)
        @checker.save!
    end

    describe "#receive" do
        it "should queue any payload it receives" do
            event1 = Event.new
            event1.agent = agents(:bob_rain_notifier_agent)
            event1.payload = "Some payload"
            event1.save!

            event2 = Event.new
            event2.agent = agents(:bob_weather_agent)
            event2.payload = "More payload"
            event2.save!

            Agents::TwilioAgent.async_receive(@checker.id, [event1.id,event2.id])
            @checker.reload.memory[:queue].should == ["Some payload", "More payload"]
        end
    end
end