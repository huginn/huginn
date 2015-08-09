require 'spec_helper'

describe User do
  describe "validations" do
    describe "invitation_code" do
      context "when configured to use invitation codes" do
        before do
          stub(User).using_invitation_code? {true}
        end
        
        it "only accepts valid invitation codes" do
          User::INVITATION_CODES.each do |v|
            is_expected.to allow_value(v).for(:invitation_code)
          end
        end
  
        it "can reject invalid invitation codes" do
          %w['foo', 'bar'].each do |v|
            is_expected.not_to allow_value(v).for(:invitation_code)
          end
        end
      end
      
      context "when configured not to use invitation codes" do
        before do
          stub(User).using_invitation_code? {false}
        end
        
        it "skips this validation" do
          %w['foo', 'bar', nil, ''].each do |v|
            is_expected.to allow_value(v).for(:invitation_code)
          end
        end
      end
    end
  end
end
