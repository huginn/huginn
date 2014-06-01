require 'spec_helper'

describe Scenario do
  describe "validations" do
    before do
      @scenario = users(:bob).scenarios.new(:name => "some scenario")
      @scenario.should be_valid
    end

    it "validates the presence of name" do
      @scenario.name = ''
      @scenario.should_not be_valid
    end

    it "validates the presence of user" do
      @scenario.user = nil
      @scenario.should_not be_valid
    end

    it "only allows Agents owned by user" do
      @scenario.agent_ids = [agents(:bob_website_agent).id]
      @scenario.should be_valid

      @scenario.agent_ids = [agents(:jane_website_agent).id]
      @scenario.should_not be_valid
    end
  end

  describe "guid" do
    it "gets created before_save, but only if it's not present" do
      scenario = users(:bob).scenarios.new(:name => "some scenario")
      scenario.guid.should be_nil
      scenario.save!
      scenario.guid.should_not be_nil

      lambda { scenario.save! }.should_not change { scenario.reload.guid }
    end
  end

  describe "counters" do
    before do
      @scenario = users(:bob).scenarios.new(:name => "some scenario")
    end

    it "maintains a counter cache on user" do
      lambda {
        @scenario.save!
      }.should change { users(:bob).reload.scenario_count }.by(1)

      lambda {
        @scenario.destroy
      }.should change { users(:bob).reload.scenario_count }.by(-1)
    end
  end
end
