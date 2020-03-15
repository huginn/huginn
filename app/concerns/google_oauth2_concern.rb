module GoogleOauth2Concern
  extend ActiveSupport::Concern

  included do
    include Oauthable

    valid_oauth_providers :google
  end

  private

  def google_oauth2_client_id
    (config = Devise.omniauth_configs[:google]) && config.strategy.client_id
  end

  def google_oauth2_client_secret
    (config = Devise.omniauth_configs[:google]) && config.strategy.client_secret
  end

  def google_oauth2_email
    if service
      service.options[:email]
    end
  end

  def google_oauth2_access_token
    if service
      service.prepare_request
      service.token
    end
  end
end
