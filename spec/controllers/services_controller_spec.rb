require 'spec_helper'

describe ServicesController do
  before do
    sign_in users(:bob)
    OmniAuth.config.test_mode = true
    request.env["omniauth.auth"] = JSON.parse(File.read(Rails.root.join('spec/data_fixtures/services/twitter.json')))
  end

  describe "GET index" do
    it "only returns sevices of the current user" do
      get :index
      assigns(:services).all? {|i| i.user.should == users(:bob) }.should == true
    end
  end

  describe "POST toggle_availability" do
    it "should work for service of the user" do
      post :toggle_availability, :id => services(:generic).to_param
      assigns(:service).should eq(services(:generic))
      redirect_to(services_path)
    end

    it "should not work for a service of another user" do
      lambda {
        post :toggle_availability, :id => services(:global).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE destroy" do
    it "destroys only services owned by the current user" do
      expect {
        delete :destroy, :id => services(:generic).to_param
      }.to change(Service, :count).by(-1)

      lambda {
        delete :destroy, :id => services(:global).to_param
      }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "accepting a callback url" do
    it "should update the user's credentials" do
      expect {
        get :callback, provider: 'twitter'
      }.to change { users(:bob).services.count }.by(1)
    end

    it "should work with an unknown provider (for now)" do
      request.env["omniauth.auth"]['provider'] = 'unknown'
      expect {
        get :callback, provider: 'unknown'
      }.to change { users(:bob).services.count }.by(1)
      users(:bob).services.first.provider.should == 'unknown'
    end
  end
end
