require 'spec_helper'

describe User do
  describe "validations" do
    describe "invitation_code" do
      it "should be required and only be valid when set to one of the allowed values" do
        users(:bob).should be_valid
        users(:bob).invitation_code = ""
        users(:bob).should_not be_valid
        users(:bob).invitation_code = "something_fake"
        users(:bob).should_not be_valid
        users(:bob).invitation_code = User::INVITATION_CODES.first
        users(:bob).should be_valid
      end
    end
  end
end