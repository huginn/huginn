require 'spec_helper'

shared_examples_for WorkingHelpers do
  describe "recent_error_logs?" do
    it "returns true if last_error_log_at is near last_event_at" do
      agent = Agent.new

      agent.last_error_log_at = 10.minutes.ago
      agent.last_event_at = 10.minutes.ago
      agent.recent_error_logs?.should be_true

      agent.last_error_log_at = 11.minutes.ago
      agent.last_event_at = 10.minutes.ago
      agent.recent_error_logs?.should be_true

      agent.last_error_log_at = 5.minutes.ago
      agent.last_event_at = 10.minutes.ago
      agent.recent_error_logs?.should be_true

      agent.last_error_log_at = 15.minutes.ago
      agent.last_event_at = 10.minutes.ago
      agent.recent_error_logs?.should be_false

      agent.last_error_log_at = 2.days.ago
      agent.last_event_at = 10.minutes.ago
      agent.recent_error_logs?.should be_false
    end
  end
  describe "received_event_without_error?" do
    before do
      @agent = Agent.new
    end

    it "should return false until the first event was received" do
      @agent.received_event_without_error?.should == false
      @agent.last_receive_at = Time.now
      @agent.received_event_without_error?.should == true
    end

    it "should return false when the last error occured after the last received event" do
      @agent.last_receive_at = Time.now - 1.minute
      @agent.last_error_log_at = Time.now
      @agent.received_event_without_error?.should == false
    end

    it "should return true when the last received event occured after the last error" do
      @agent.last_receive_at = Time.now
      @agent.last_error_log_at = Time.now - 1.minute
      @agent.received_event_without_error?.should == true
    end
  end

end
