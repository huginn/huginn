require 'spec_helper'

describe AgentLog do
  describe "validations" do
    before do
      @log = AgentLog.new(:agent => agents(:jane_website_agent), :message => "The agent did something", :level => 3)
      @log.should be_valid
    end

    it "requires an agent" do
      @log.agent = nil
      @log.should_not be_valid
      @log.should have(1).error_on(:agent)
    end

    it "requires a message" do
      @log.message = ""
      @log.should_not be_valid
      @log.message = nil
      @log.should_not be_valid
      @log.should have(1).error_on(:message)
    end

    it "requires a valid log level" do
      @log.level = nil
      @log.should_not be_valid
      @log.should have(1).error_on(:level)

      @log.level = -1
      @log.should_not be_valid
      @log.should have(1).error_on(:level)

      @log.level = 5
      @log.should_not be_valid
      @log.should have(1).error_on(:level)

      @log.level = 4
      @log.should be_valid

      @log.level = 0
      @log.should be_valid
    end
  end

  describe "#log_for_agent" do
    it "creates AgentLogs" do
      log = AgentLog.log_for_agent(agents(:jane_website_agent), "some message", :level => 4, :outbound_event => events(:jane_website_agent_event))
      log.should_not be_new_record
      log.agent.should == agents(:jane_website_agent)
      log.outbound_event.should == events(:jane_website_agent_event)
      log.message.should == "some message"
      log.level.should == 4
    end

    it "cleans up old logs when there are more than log_length" do
      stub(AgentLog).log_length { 4 }
      AgentLog.log_for_agent(agents(:jane_website_agent), "message 1")
      AgentLog.log_for_agent(agents(:jane_website_agent), "message 2")
      AgentLog.log_for_agent(agents(:jane_website_agent), "message 3")
      AgentLog.log_for_agent(agents(:jane_website_agent), "message 4")
      agents(:jane_website_agent).logs.order("agent_logs.id desc").first.message.should == "message 4"
      agents(:jane_website_agent).logs.order("agent_logs.id desc").last.message.should == "message 1"
      AgentLog.log_for_agent(agents(:jane_website_agent), "message 5")
      agents(:jane_website_agent).logs.order("agent_logs.id desc").first.message.should == "message 5"
      agents(:jane_website_agent).logs.order("agent_logs.id desc").last.message.should == "message 2"
      AgentLog.log_for_agent(agents(:jane_website_agent), "message 6")
      agents(:jane_website_agent).logs.order("agent_logs.id desc").first.message.should == "message 6"
      agents(:jane_website_agent).logs.order("agent_logs.id desc").last.message.should == "message 3"
    end

    it "updates Agents' last_error_log_at when an error is logged" do
      AgentLog.log_for_agent(agents(:jane_website_agent), "some message", :level => 3, :outbound_event => events(:jane_website_agent_event))
      agents(:jane_website_agent).reload.last_error_log_at.should be_nil

      AgentLog.log_for_agent(agents(:jane_website_agent), "some message", :level => 4, :outbound_event => events(:jane_website_agent_event))
      agents(:jane_website_agent).reload.last_error_log_at.to_i.should be_within(2).of(Time.now.to_i)
    end
  end

  describe "#log_length" do
    it "defaults to 200" do
      AgentLog.log_length.should == 200
    end
  end
end
