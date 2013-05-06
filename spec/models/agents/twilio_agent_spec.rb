require 'spec_helper'

describe Agents::TwilioAgent do
    before do
        @checker = Agents::TwilioAgent.new(:name => "somename", :options => {:account_sid => "x",:auth_token => "x",:sender_cell => "x", :receiver_cell => "x", :expected_receive_period_in_days => "1"})
        @checker.user = users(:bob)
        @checker.save!

        @event = Event.new
        @event.agent = agents(:bob_weather_agent)
        @event.payload = {:message => "Gonna rain.."}
        @event.save!

        stub.any_instance_of(Agents::TwilioAgent).send_message {}
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

    describe "#working?" do
        it "checks if events have been received within expected receive period" do
            @checker.should_not be_working # No events received
            Agents::TwilioAgent.async_receive @checker.id, [@event.id]
            @checker.reload.should be_working # Just received events
            two_days_from_now = 2.days.from_now
            stub(Time).now { two_days_from_now }
            @checker.reload.should_not be_working # More time have passed than expected receive period without sign of any new event
        end
    end

    describe "#check" do
        before do
            Agents::TwilioAgent.async_receive @checker.id, [@event.id]
        end
        it "should send text message and Memory should be empty after that" do
            @checker.reload.memory[:queue].should == [{:message => "Gonna rain.."}]
            Agents::TwilioAgent.async_check(@checker.id)
            @checker.reload.memory[:queue].should == []

        end
    end
end