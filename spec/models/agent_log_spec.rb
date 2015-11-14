# -*- coding: utf-8 -*-
require 'rails_helper'

describe AgentLog do
  describe "validations" do
    before do
      @log = AgentLog.new(:agent => agents(:jane_website_agent), :message => "The agent did something", :level => 3)
      expect(@log).to be_valid
    end

    it "requires an agent" do
      @log.agent = nil
      expect(@log).not_to be_valid
      expect(@log).to have(1).error_on(:agent)
    end

    it "requires a message" do
      @log.message = ""
      expect(@log).not_to be_valid
      @log.message = nil
      expect(@log).not_to be_valid
      expect(@log).to have(1).error_on(:message)
    end

    it "requires a valid log level" do
      @log.level = nil
      expect(@log).not_to be_valid
      expect(@log).to have(1).error_on(:level)

      @log.level = -1
      expect(@log).not_to be_valid
      expect(@log).to have(1).error_on(:level)

      @log.level = 5
      expect(@log).not_to be_valid
      expect(@log).to have(1).error_on(:level)

      @log.level = 4
      expect(@log).to be_valid

      @log.level = 0
      expect(@log).to be_valid
    end
  end

  it "replaces invalid byte sequences in a message" do
    log = AgentLog.new(:agent => agents(:jane_website_agent), level: 3)
    log.message = "\u{3042}\xffA\x95"
    expect { log.save! }.not_to raise_error
    expect(log.message).to eq("\u{3042}<ff>A\<95>")
  end

  it "truncates message to a reasonable length" do
    log = AgentLog.new(:agent => agents(:jane_website_agent), :level => 3)
    log.message = "a" * 11_000
    log.save!
    expect(log.message.length).to eq(10_000)
  end

  describe "#log_for_agent" do
    it "creates AgentLogs" do
      log = AgentLog.log_for_agent(agents(:jane_website_agent), "some message", :level => 4, :outbound_event => events(:jane_website_agent_event))
      expect(log).not_to be_new_record
      expect(log.agent).to eq(agents(:jane_website_agent))
      expect(log.outbound_event).to eq(events(:jane_website_agent_event))
      expect(log.message).to eq("some message")
      expect(log.level).to eq(4)
    end

    it "cleans up old logs when there are more than log_length" do
      stub(AgentLog).log_length { 4 }
      AgentLog.log_for_agent(agents(:jane_website_agent), "message 1")
      AgentLog.log_for_agent(agents(:jane_website_agent), "message 2")
      AgentLog.log_for_agent(agents(:jane_website_agent), "message 3")
      AgentLog.log_for_agent(agents(:jane_website_agent), "message 4")
      expect(agents(:jane_website_agent).logs.order("agent_logs.id desc").first.message).to eq("message 4")
      expect(agents(:jane_website_agent).logs.order("agent_logs.id desc").last.message).to eq("message 1")
      AgentLog.log_for_agent(agents(:jane_website_agent), "message 5")
      expect(agents(:jane_website_agent).logs.order("agent_logs.id desc").first.message).to eq("message 5")
      expect(agents(:jane_website_agent).logs.order("agent_logs.id desc").last.message).to eq("message 2")
      AgentLog.log_for_agent(agents(:jane_website_agent), "message 6")
      expect(agents(:jane_website_agent).logs.order("agent_logs.id desc").first.message).to eq("message 6")
      expect(agents(:jane_website_agent).logs.order("agent_logs.id desc").last.message).to eq("message 3")
    end

    it "updates Agents' last_error_log_at when an error is logged" do
      AgentLog.log_for_agent(agents(:jane_website_agent), "some message", :level => 3, :outbound_event => events(:jane_website_agent_event))
      expect(agents(:jane_website_agent).reload.last_error_log_at).to be_nil

      AgentLog.log_for_agent(agents(:jane_website_agent), "some message", :level => 4, :outbound_event => events(:jane_website_agent_event))
      expect(agents(:jane_website_agent).reload.last_error_log_at.to_i).to be_within(2).of(Time.now.to_i)
    end

    it "accepts objects as well as strings" do
      log = AgentLog.log_for_agent(agents(:jane_website_agent), events(:bob_website_agent_event).payload)
      expect(log.message).to include('"title"=>"foo"')
    end
  end

  describe "#log_length" do
    it "defaults to 200" do
      expect(AgentLog.log_length).to eq(200)
    end
  end
end
