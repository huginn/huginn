require 'spec_helper'

describe User do
  describe "validations" do
    describe "invitation_code" do
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
    end
  end
end
