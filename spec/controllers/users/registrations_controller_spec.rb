require 'rails_helper'

module Users
  describe RegistrationsController do
    include Devise::TestHelpers

    describe "POST create" do
      context 'with valid params' do
        it "imports the default scenario for the new user" do
          mock(DefaultScenarioImporter).import(is_a(User))

          @request.env["devise.mapping"] = Devise.mappings[:user]
          post :create, :user => {username: 'jdoe', email: 'jdoe@example.com',
            password: 's3cr3t55', password_confirmation: 's3cr3t55', admin: false, invitation_code: 'try-huginn'}
        end
      end

      context 'with invalid params' do
        it "does not import the default scenario" do
          stub(DefaultScenarioImporter).import(is_a(User)) { fail "Should not attempt import" }

          @request.env["devise.mapping"] = Devise.mappings[:user]
          setup_controller_for_warden
          post :create, :user => {}
        end
      end
    end
  end
end
