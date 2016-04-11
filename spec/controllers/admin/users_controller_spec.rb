require 'rails_helper'

describe Admin::UsersController do
  describe 'POST #create' do
    context 'with valid user params' do
      it 'imports the default scenario for the new user' do
        mock(DefaultScenarioImporter).import(is_a(User))
        sign_in users(:jane)
        post :create, :user => {username: 'jdoe', email: 'jdoe@example.com',
                             password: 's3cr3t55', password_confirmation: 's3cr3t55', admin: false }
      end
    end
    
    context 'with invalid user params' do
      it 'does not import the default scenario' do
        stub(DefaultScenarioImporter).import(is_a(User)) { fail "Should not attempt import" }
        sign_in users(:jane)
        post :create, :user => {}
      end
    end
  end
end
