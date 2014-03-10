require 'spec_helper'

describe Agents::SentimentAgent do
    before do
        @valid_params = {
            :name => "somename",
            :options => {
                :content => "$.message",
                :expected_receive_period_in_days => 1
            }
        }

        @checker = Agents::SentimentAgent.new(@valid_params)
        @checker.user = users(:jane)
        @checker.save!

        @event = Event.new
        @event.agent = agents(:jane_weather_agent)
        @event.payload = {
            :message => "value1"
        }
        @event.save!
    end

    describe "#working?" do
        it "checks if events have been received within expected receive period" do
            @checker.should_not be_working
            Agents::SentimentAgent.async_receive @checker.id, [@event.id]
            @checker.reload.should be_working
            two_days_from_now = 2.days.from_now
            stub(Time).now { two_days_from_now }  
            @checker.reload.should_not be_working
        end
    end

    describe "validation" do
        before do
            @checker.should be_valid
        end

        it "should validate presence of content key" do
            @checker.options[:content] = nil
            @checker.should_not be_valid
        end

        it "should validate presence of expected_receive_period_in_days key" do
            @checker.options[:expected_receive_period_in_days] = nil
            @checker.should_not be_valid
        end
    end

    describe "#receive" do
        it "checks if content key is working fine" do
            @checker.receive([@event])
            Event.last.payload[:content].should == "value1"
            Event.last.payload[:original_event].should == { 'message' => "value1" }
        end
        it "should handle multiple events" do
            event1 = Event.new
            event1.agent = agents(:bob_weather_agent)
            event1.payload = {
                :message => "The quick brown fox jumps over the lazy dog"
            }

            event2 = Event.new
            event2.agent = agents(:jane_weather_agent)
            event2.payload = {
                :message => "The quick brown fox jumps over the lazy dog"
            }

            lambda {
                @checker.receive([@event,event1,event2])
            }.should change { Event.count }.by(3)
        end
    end
end