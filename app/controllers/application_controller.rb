class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper :all

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up) { |u| u.permit(:username, :email, :password, :password_confirmation, :remember_me, :invitation_code) }
    devise_parameter_sanitizer.for(:sign_in) { |u| u.permit(:login, :username, :email, :password, :remember_me) }
    devise_parameter_sanitizer.for(:account_update) { |u| u.permit(:username, :email, :password, :password_confirmation, :current_password) }
  end

  def upgrade_warning
    return unless current_user
    twitter_oauth_check
    basecamp_auth_check
  end

  private
  def twitter_oauth_check
    if ENV['TWITTER_OAUTH_KEY'].blank? || ENV['TWITTER_OAUTH_SECRET'].blank?
      if @twitter_agent = current_user.agents.where("type like 'Agents::Twitter%'").first
        @twitter_oauth_key    = @twitter_agent.options['consumer_key'].presence || @twitter_agent.credential('twitter_consumer_key')
        @twitter_oauth_secret = @twitter_agent.options['consumer_secret'].presence || @twitter_agent.credential('twitter_consumer_secret')
      end
    end
  end

  def basecamp_auth_check
    if ENV['THIRTY_SEVEN_SIGNALS_OAUTH_KEY'].blank? || ENV['THIRTY_SEVEN_SIGNALS_OAUTH_SECRET'].blank?
      @basecamp_agent = current_user.agents.where(type: 'Agents::BasecampAgent').first
    end
  end

end
