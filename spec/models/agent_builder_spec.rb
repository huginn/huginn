require 'rails_helper'

describe AgentBuilder do
  let(:user) { User.new }

  context "when the specified type inherits from Agent" do
    it "builds an agent of the specified type" do
      agent = AgentBuilder.build_for_type('Agents::ManualEventAgent', user, name: 'Dry-Runner')
      expect(agent).to be_kind_of(Agents::ManualEventAgent)
      expect(agent.user).to eq(user)
      expect(agent.name).to eq('Dry-Runner')
      expect(agent.errors_on(:type).size).to eq(0)
    end

    context "when the specified type does not include the Agents module" do
      it "builds an agent of the specified type" do
        agent = AgentBuilder.build_for_type('ManualEventAgent', user, name: 'Dry-Runner')
        expect(agent).to be_kind_of(Agents::ManualEventAgent)
      end
    end
  end

  context "when the specified type is an Agent (not subclass)" do
    it "builds an agent of type Agent with an error on type" do
      agent = AgentBuilder.build_for_type('Agent', user, name: 'ParentAgent')
      expect(agent).to be_kind_of(Agent)
      expect(agent.user).to eq(user)
      expect(agent.name).to eq('ParentAgent')
      expect(agent.errors_on(:type)).to eq(["is not a valid type"])
    end
  end

  context "when the specified type is in the Agents module, but is not a real agent" do
    it "builds an agent of type Agent with an error on type" do
      agent = AgentBuilder.build_for_type('Agents::NotRealAgent', user, name: 'Not a real agent')
      expect(agent).to be_kind_of(Agent)
      expect(agent.errors_on(:type)).to eq(["is not a valid type"])
    end
  end

  context "when the specified type is real, but not an Agent" do
    it "builds an agent of type Agent with an error on type" do
      agent = AgentBuilder.build_for_type('Object', user, name: 'Not a real agent')
      expect(agent).to be_kind_of(Agent)
      expect(agent.errors_on(:type)).to eq(["is not a valid type"])
    end
  end

  context "when the specified type is not real" do
    it "builds an agent of type Agent with an error on type" do
      agent = AgentBuilder.build_for_type('FakeObjectType', user, name: 'Not a real agent')
      expect(agent).to be_kind_of(Agent)
      expect(agent.errors_on(:type)).to eq(["is not a valid type"])
    end
  end
end
