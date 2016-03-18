require 'rails_helper'

shared_examples_for WorkingHelpers do
  describe "recent_error_logs?" do
    it "returns true if last_error_log_at is near last_event_at" do
      agent = described_class.new

      agent.last_error_log_at = 10.minutes.ago
      agent.last_event_at = 10.minutes.ago
      expect(agent.recent_error_logs?).to be_truthy

      agent.last_error_log_at = 11.minutes.ago
      agent.last_event_at = 10.minutes.ago
      expect(agent.recent_error_logs?).to be_truthy

      agent.last_error_log_at = 5.minutes.ago
      agent.last_event_at = 10.minutes.ago
      expect(agent.recent_error_logs?).to be_truthy

      agent.last_error_log_at = 15.minutes.ago
      agent.last_event_at = 10.minutes.ago
      expect(agent.recent_error_logs?).to be_falsey

      agent.last_error_log_at = 2.days.ago
      agent.last_event_at = 10.minutes.ago
      expect(agent.recent_error_logs?).to be_falsey
    end
  end

  describe "received_event_without_error?" do
    before do
      @agent = described_class.new
    end

    it "should return false until the first event was received" do
      expect(@agent.received_event_without_error?).to eq(false)
      @agent.last_receive_at = Time.now
      expect(@agent.received_event_without_error?).to eq(true)
    end

    it "should return false when the last error occured after the last received event" do
      @agent.last_receive_at = Time.now - 1.minute
      @agent.last_error_log_at = Time.now
      expect(@agent.received_event_without_error?).to eq(false)
    end

    it "should return true when the last received event occured after the last error" do
      @agent.last_receive_at = Time.now
      @agent.last_error_log_at = Time.now - 1.minute
      expect(@agent.received_event_without_error?).to eq(true)
    end
  end

  describe "checked_without_error?" do
    before do
      @agent = described_class.new
    end

    it "should return false until the first time check ran" do
      expect(@agent.checked_without_error?).to eq(false)
      @agent.last_check_at = Time.now
      expect(@agent.checked_without_error?).to eq(true)
    end

    it "should return false when the last error occured after the check" do
      @agent.last_check_at = Time.now - 1.minute
      @agent.last_error_log_at = Time.now
      expect(@agent.checked_without_error?).to eq(false)
    end

    it "should return true when the last check occured after the last error" do
      @agent.last_check_at = Time.now
      @agent.last_error_log_at = Time.now - 1.minute
      expect(@agent.checked_without_error?).to eq(true)
    end
  end
end
