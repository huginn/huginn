require 'rails_helper'

describe Admin::UsersController do
  describe 'POST #create' do
    context 'with valid user params' do
      it 'imports the default scenario for the new user' do
        mock(DefaultScenarioImporter).import(is_a(User))
        sign_in users(:jane)
        post :create, params: {:user => {username: 'jdoe', email: 'jdoe@example.com',
                                         password: 's3cr3t55', password_confirmation: 's3cr3t55', admin: false }}
      end
    end
    
    context 'with invalid user params' do
      it 'does not import the default scenario' do
        stub(DefaultScenarioImporter).import(is_a(User)) { fail "Should not attempt import" }
        sign_in users(:jane)
        post :create, params: {:user => {username: 'user'}}
      end
    end
  end

  describe 'GET #switch_to_user' do
    it "switches to another user" do
      sign_in users(:jane)

      get :switch_to_user, params: {:id => users(:bob).id}
      expect(response).to redirect_to(agents_path)
      expect(subject.session[:original_admin_user_id]).to eq(users(:jane).id)
    end

    it "does not switch if not admin" do
      sign_in users(:bob)

      get :switch_to_user, params: {:id => users(:jane).id}
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'GET #switch_back' do
    it "switches to another user and back" do
      sign_in users(:jane)

      get :switch_to_user, params: {:id => users(:bob).id}
      expect(response).to redirect_to(agents_path)
      expect(subject.session[:original_admin_user_id]).to eq(users(:jane).id)

      get :switch_back
      expect(response).to redirect_to(admin_users_path)
      expect(subject.session[:original_admin_user_id]).to be_nil
    end

    it "does not switch_back without having switched" do
      sign_in users(:bob)
      get :switch_back
      expect(response).to redirect_to(root_path)
    end
  end
end
