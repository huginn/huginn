require 'spec_helper'

describe Scenario do
  let(:new_instance) { users(:bob).scenarios.build(:name => "some scenario") }

  it_behaves_like HasGuid

  describe "validations" do
    before do
      expect(new_instance).to be_valid
    end

    it "validates the presence of name" do
      new_instance.name = ''
      expect(new_instance).not_to be_valid
    end

    it "validates the presence of user" do
      new_instance.user = nil
      expect(new_instance).not_to be_valid
    end

    it "validates tag_fg_color is hex color" do
      new_instance.tag_fg_color = '#N07H3X'
      expect(new_instance).not_to be_valid
      new_instance.tag_fg_color = '#BADA55'
      expect(new_instance).to be_valid
    end

    it "allows nil tag_fg_color" do
      new_instance.tag_fg_color = nil
      expect(new_instance).to be_valid
    end

    it "validates tag_bg_color is hex color" do
      new_instance.tag_bg_color = '#N07H3X'
      expect(new_instance).not_to be_valid
      new_instance.tag_bg_color = '#BADA55'
      expect(new_instance).to be_valid
    end

    it "allows nil tag_bg_color" do
      new_instance.tag_bg_color = nil
      expect(new_instance).to be_valid
    end

    it "only allows Agents owned by user" do
      new_instance.agent_ids = [agents(:bob_website_agent).id]
      expect(new_instance).to be_valid

      new_instance.agent_ids = [agents(:jane_website_agent).id]
      expect(new_instance).not_to be_valid
    end
  end

  describe "counters" do
    it "maintains a counter cache on user" do
      expect {
        new_instance.save!
      }.to change { users(:bob).reload.scenario_count }.by(1)

      expect {
        new_instance.destroy
      }.to change { users(:bob).reload.scenario_count }.by(-1)
    end
  end
end
