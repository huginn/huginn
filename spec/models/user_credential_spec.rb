require 'rails_helper'

describe UserCredential do
  subject(:user_credential) do
    described_class.new(
      credential_name: 'new_key',
      credential_value: 'secret',
      user: users(:bob)
    )
  end

  describe "validation" do
    it "requires credential_name" do
      user_credential.credential_name = nil

      expect(user_credential).not_to be_valid
      expect(user_credential.errors[:credential_name]).to include("can't be blank")
    end

    it "requires credential_value" do
      user_credential.credential_value = nil

      expect(user_credential).not_to be_valid
      expect(user_credential.errors[:credential_value]).to include("can't be blank")
    end

    it "requires user_id" do
      user_credential.user = nil

      expect(user_credential).not_to be_valid
      expect(user_credential.errors[:user_id]).to include("can't be blank")
    end

    it "requires credential_name to be unique per user" do
      user_credential.credential_name = user_credentials(:bob_aws_key).credential_name

      expect(user_credential).not_to be_valid
      expect(user_credential.errors[:credential_name]).to include('has already been taken')
    end

    it "allows the same credential_name for another user" do
      user_credential.credential_name = user_credentials(:bob_aws_key).credential_name
      user_credential.user = User.create!(
        username: 'alice',
        email: 'alice@example.com',
        password: '12345678',
        password_confirmation: '12345678',
        invitation_code: User::INVITATION_CODES.last
      )

      expect(user_credential).to be_valid
    end
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
