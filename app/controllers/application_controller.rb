class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper :all

  protected
  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up) << [:username, :email, :invitation_code]
  end
end
