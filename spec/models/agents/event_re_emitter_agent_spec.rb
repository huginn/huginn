require 'spec_helper'

describe Agents::EventFormattingAgent do
  before do
    @valid_params = {
        :name => "somename",
        :options => {
            'expected_receive_period_in_days' => "2"
        }
    }
    @checker = Agents::EventReEmitterAgent.new(@valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:jane_weather_agent)
    @event.created_at = Time.now
    @event.payload = {
        :content => {
            :text => "Some Lorem Ipsum",
            :name => "somevalue",
        },
        :date => {
            :epoch => "1357959600",
            :pretty => "10:00 PM EST on January 11, 2013"
        },
        :conditions => "someothervalue"
    }
  end

  describe "#receive" do
    it "should re-emit events received" do
      lambda { @checker.receive([@event]) }.should change { Event.count }.by(1)
      Event.last.payload.should == @event.payload
    end

    it "should save events it has re-emitted" do
      @checker.receive([@event])
      @checker.events.last.payload.should == @event.payload
    end
  end

  describe "#check" do
    it "should re-emit events on check without duplication" do
      @checker.receive([@event])
      lambda { @checker.check }.should_not change { Event.count }
      event = Event.last
      
      @checker.check
      new_event = Event.last
      new_event.should_not == event
    end
  end
end