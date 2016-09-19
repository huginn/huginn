require 'rails_helper'

describe User do
  let(:bob) { users(:bob) }

  describe "validations" do
    describe "invitation_code" do
      context "when configured to use invitation codes" do
        before do
          stub(User).using_invitation_code? {true}
        end
        
        it "only accepts valid invitation codes" do
          User::INVITATION_CODES.each do |v|
            should allow_value(v).for(:invitation_code)
          end
        end
  
        it "can reject invalid invitation codes" do
          %w['foo', 'bar'].each do |v|
            should_not allow_value(v).for(:invitation_code)
          end
        end

        it "requires no authentication code when requires_no_invitation_code! is called" do
          u = User.new(username: 'test', email: 'test@test.com', password: '12345678', password_confirmation: '12345678')
          u.requires_no_invitation_code!
          expect(u).to be_valid
        end
      end
      
      context "when configured not to use invitation codes" do
        before do
          stub(User).using_invitation_code? {false}
        end
        
        it "skips this validation" do
          %w['foo', 'bar', nil, ''].each do |v|
            should allow_value(v).for(:invitation_code)
          end
        end
      end
    end
  end

  context '#deactivate!' do
    it "deactivates the user and all her agents" do
      agent = agents(:jane_website_agent)
      users(:jane).deactivate!
      agent.reload
      expect(agent.deactivated).to be_truthy
      expect(users(:jane).deactivated_at).not_to be_nil
    end
  end

  context '#activate!' do
    before do
      users(:bob).deactivate!
    end

    it 'activates the user and all his agents' do
      agent = agents(:bob_website_agent)
      users(:bob).activate!
      agent.reload
      expect(agent.deactivated).to be_falsy
      expect(users(:bob).deactivated_at).to be_nil
    end
  end

  context '#undefined_agent_types' do
    it 'returns an empty array when no agents are undefined' do
      expect(bob.undefined_agent_types).to be_empty
    end

    it 'returns the undefined agent types' do
      agent = agents(:bob_website_agent)
      agent.update_attribute(:type, 'Agents::UndefinedAgent')
      expect(bob.undefined_agent_types).to match_array(['Agents::UndefinedAgent'])
    end
  end

  context '#undefined_agents' do
    it 'returns an empty array when no agents are undefined' do
      expect(bob.undefined_agents).to be_empty
    end

    it 'returns the undefined agent types' do
      agent = agents(:bob_website_agent)
      agent.update_attribute(:type, 'Agents::UndefinedAgent')
      expect(bob.undefined_agents).not_to be_empty
      expect(bob.undefined_agents.first).to be_a(Agent)
    end
  end
end
