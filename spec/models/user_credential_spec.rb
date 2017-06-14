require 'rails_helper'

describe UserCredential do
  describe "validation" do
    it { should validate_uniqueness_of(:credential_name).scoped_to(:user_id) }
    it { should validate_presence_of(:credential_name) }
    it { should validate_presence_of(:credential_value) }
    it { should validate_presence_of(:user_id) }
  end

  describe "cleaning fields" do
    it "should trim whitespace" do
      user_credential = user_credentials(:bob_aws_key)
      user_credential.credential_name = " new name "
      user_credential.credential_value = " new value "
      user_credential.save!
      expect(user_credential.credential_name).to eq("new name")
      expect(user_credential.credential_value).to eq("new value")
    end
  end
end
