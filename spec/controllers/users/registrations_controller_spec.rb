require 'rails_helper'

module Users
  describe RegistrationsController do
    include Devise::TestHelpers

    describe "POST create" do
      before do
        @request.env["devise.mapping"] = Devise.mappings[:user]
      end

      context 'with valid params' do
        it "imports the default scenario for the new user" do
          mock(DefaultScenarioImporter).import(is_a(User))

          post :create, :user => {username: 'jdoe', email: 'jdoe@example.com',
            password: 's3cr3t55', password_confirmation: 's3cr3t55', invitation_code: 'try-huginn'}
        end
      end

      context 'with invalid params' do
        it "does not import the default scenario" do
          stub(DefaultScenarioImporter).import(is_a(User)) { fail "Should not attempt import" }

          setup_controller_for_warden
          post :create, :user => {}
        end

        it 'does not allow to set the admin flag' do
          expect { post :create, :user => {admin: 'true'} }.to raise_error(ActionController::UnpermittedParameters)
        end
      end
    end
  end
end
