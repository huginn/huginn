require 'rails_helper'

describe Admin::UsersController do
  describe 'POST #create' do
    context 'with valid user params' do
      it 'imports the default scenario for the new user' do
        expect(DefaultScenarioImporter).to receive(:import).with(kind_of(User))
        sign_in users(:jane), scope: :user
        post :create, params: {:user => {username: 'jdoe', email: 'jdoe@example.com',
                                         password: 's3cr3t55', password_confirmation: 's3cr3t55', admin: false }}
      end
    end
    
    context 'with invalid user params' do
      it 'does not import the default scenario' do
        allow(DefaultScenarioImporter).to receive(:import).with(kind_of(User)) { fail "Should not attempt import" }
        sign_in users(:jane), scope: :user
        post :create, params: {:user => {username: 'user'}}
      end
    end
  end

  describe 'POST #switch_to_user' do
    it "does not switch if not admin" do
      sign_in users(:bob), scope: :user

      post :switch_to_user, params: {:id => users(:jane).id}
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST #switch_back' do
    it "switches to another user and back" do
      sign_in users(:jane), scope: :user

      post :switch_to_user, params: {:id => users(:bob).id}
      expect(response).to redirect_to(agents_path)
      expect(subject.session[:original_admin_user_id]).to eq(users(:jane).id)

      post :switch_back
      expect(response).to redirect_to(admin_users_path)
      expect(subject.session[:original_admin_user_id]).to be_nil
    end

    it "does not switch_back without having switched" do
      sign_in users(:bob), scope: :user
      post :switch_back
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'impersonation request protection' do
    around do |example|
      previous = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      begin
        example.run
      ensure
        ActionController::Base.allow_forgery_protection = previous
      end
    end

    it 'rejects switching users without a CSRF token' do
      sign_in users(:jane), scope: :user

      expect {
        post :switch_to_user, params: { id: users(:bob).id }
      }.to raise_error(ActionController::InvalidAuthenticityToken)
      expect(controller.current_user).to eq(users(:jane))
      expect(session[:original_admin_user_id]).to be_nil
    end

    it 'rejects switching back without a CSRF token' do
      sign_in users(:bob), scope: :user
      session[:original_admin_user_id] = users(:jane).id

      expect {
        post :switch_back
      }.to raise_error(ActionController::InvalidAuthenticityToken)
      expect(controller.current_user).to eq(users(:bob))
      expect(session[:original_admin_user_id]).to eq(users(:jane).id)
    end

    it 'accepts switching users and back with valid CSRF tokens' do
      sign_in users(:jane), scope: :user
      token = controller.send(:form_authenticity_token)

      post :switch_to_user, params: { id: users(:bob).id, authenticity_token: token }
      expect(response).to redirect_to(agents_path)
      expect(session[:original_admin_user_id]).to eq(users(:jane).id)

      post :switch_back, params: { authenticity_token: token }
      expect(response).to redirect_to(admin_users_path)
      expect(session[:original_admin_user_id]).to be_nil
    end
  end
end
