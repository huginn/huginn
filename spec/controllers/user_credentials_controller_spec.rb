require 'rails_helper'

describe UserCredentialsController do
  def valid_attributes(options = {})
    {
      :credential_name => "some_name",
      :credential_value => "some_value"
    }.merge(options)
  end

  before do
    sign_in users(:bob)
  end

  describe "GET index" do
    it "only returns UserCredentials for the current user" do
      get :index
      expect(assigns(:user_credentials).all? {|i| expect(i.user).to eq(users(:bob)) }).to be_truthy
    end
  end

  describe "GET edit" do
    it "only shows UserCredentials for the current user" do
      get :edit, :id => user_credentials(:bob_aws_secret).to_param
      expect(assigns(:user_credential)).to eq(user_credentials(:bob_aws_secret))

      expect {
        get :edit, :id => user_credentials(:jane_aws_secret).to_param
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST create" do
    it "creates UserCredentials for the current user" do
      expect {
        post :create, :user_credential => valid_attributes
      }.to change { users(:bob).user_credentials.count }.by(1)
    end

    it "shows errors" do
      expect {
        post :create, :user_credential => valid_attributes(:credential_name => "")
      }.not_to change { users(:bob).user_credentials.count }
      expect(assigns(:user_credential)).to have(1).errors_on(:credential_name)
      expect(response).to render_template("new")
    end

    it "will not create UserCredentials for other users" do
      expect {
        post :create, :user_credential => valid_attributes(:user_id => users(:jane).id)
      }.to raise_error(ActiveModel::MassAssignmentSecurity::Error)
    end
  end

  describe "PUT update" do
    it "updates attributes on UserCredentials for the current user" do
      post :update, :id => user_credentials(:bob_aws_key).to_param, :user_credential => { :credential_name => "new_name" }
      expect(response).to redirect_to(user_credentials_path)
      expect(user_credentials(:bob_aws_key).reload.credential_name).to eq("new_name")

      expect {
        post :update, :id => user_credentials(:jane_aws_key).to_param, :user_credential => { :credential_name => "new_name" }
      }.to raise_error(ActiveRecord::RecordNotFound)
      expect(user_credentials(:jane_aws_key).reload.credential_name).not_to eq("new_name")
    end

    it "shows errors" do
      post :update, :id => user_credentials(:bob_aws_key).to_param, :user_credential => { :credential_name => "" }
      expect(assigns(:user_credential)).to have(1).errors_on(:credential_name)
      expect(response).to render_template("edit")
    end
  end

  describe "DELETE destroy" do
    it "destroys only UserCredentials owned by the current user" do
      expect {
        delete :destroy, :id => user_credentials(:bob_aws_key).to_param
      }.to change(UserCredential, :count).by(-1)

      expect {
        delete :destroy, :id => user_credentials(:jane_aws_key).to_param
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
