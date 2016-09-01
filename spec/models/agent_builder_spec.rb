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

    context "when the specified type is not fully qualified" do
      it "raises an error" do
        expect { AgentBuilder.build_for_type('ManualEventAgent', user, name: 'InvalidAgent') }.to raise_error(NameError)
      end
    end
  end

  context "when the specified type is not a subclass of Agent" do
    it "raises an error" do
      expect { AgentBuilder.build_for_type('Agent', user, name: 'InvalidAgent') }.to raise_error(NameError)
      expect { AgentBuilder.build_for_type('Agents::NotRealAgent', user, name: 'InvalidAgent') }.to raise_error(NameError)
      expect { AgentBuilder.build_for_type('Object', user, name: 'InvalidAgent') }.to raise_error(NameError)
      expect { AgentBuilder.build_for_type('FakeObjectType', user, name: 'InvalidAgent') }.to raise_error(NameError)
    end
  end
end
