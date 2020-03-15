module GoogleOauth2Concern
  extend ActiveSupport::Concern

  included do
    include Oauthable

    validate :validate_google_oauth2_options

    valid_oauth_providers :google

    gem_dependency_check { Devise.omniauth_providers.include?(:google) }
  end

  private

  def validate_google_oauth2_options
    unless google_oauth2_client_id.present? &&
      google_oauth2_client_secret.present? &&
      google_oauth2_access_token.present?
      errors.add(:base, "Evernote ENV variables and a Service are required")
    end
  end

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
