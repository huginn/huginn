require 'spec_helper'

describe Scenario do
  let(:new_instance) { users(:bob).scenarios.build(:name => "some scenario") }

  it_behaves_like HasGuid

  describe "validations" do
    before do
      new_instance.should be_valid
    end

    it "validates the presence of name" do
      new_instance.name = ''
      new_instance.should_not be_valid
    end

    it "validates the presence of user" do
      new_instance.user = nil
      new_instance.should_not be_valid
    end

    it "only allows Agents owned by user" do
      new_instance.agent_ids = [agents(:bob_website_agent).id]
      new_instance.should be_valid

      new_instance.agent_ids = [agents(:jane_website_agent).id]
      new_instance.should_not be_valid
    end
  end

  describe "counters" do
    it "maintains a counter cache on user" do
      lambda {
        new_instance.save!
      }.should change { users(:bob).reload.scenario_count }.by(1)

      lambda {
        new_instance.destroy
      }.should change { users(:bob).reload.scenario_count }.by(-1)
    end
  end
end
