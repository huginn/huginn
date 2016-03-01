require 'rails_helper'

describe User do
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
end
