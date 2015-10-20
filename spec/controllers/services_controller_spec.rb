require 'rails_helper'

describe ServicesController do
  before do
    sign_in users(:bob)
  end

  describe "GET index" do
    it "only returns sevices of the current user" do
      get :index
      expect(assigns(:services).all? {|i| expect(i.user).to eq(users(:bob)) }).to eq(true)
    end
  end

  describe "POST toggle_availability" do
    it "should work for service of the user" do
      post :toggle_availability, :id => services(:generic).to_param
      expect(assigns(:service)).to eq(services(:generic))
      redirect_to(services_path)
    end

    it "should not work for a service of another user" do
      expect {
        post :toggle_availability, :id => services(:global).to_param
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE destroy" do
    it "destroys only services owned by the current user" do
      expect {
        delete :destroy, :id => services(:generic).to_param
      }.to change(Service, :count).by(-1)

      expect {
        delete :destroy, :id => services(:global).to_param
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
