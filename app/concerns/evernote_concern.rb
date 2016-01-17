module EvernoteConcern
  extend ActiveSupport::Concern

  included do
    include Oauthable

    validate :validate_evernote_options

    valid_oauth_providers :evernote

    gem_dependency_check { defined?(EvernoteOAuth) && Devise.omniauth_providers.include?(:evernote) }
  end

  def evernote_client
    EvernoteOAuth::Client.new(
      token:           evernote_oauth_token,
      consumer_key:    evernote_consumer_key,
      consumer_secret: evernote_consumer_secret,
      sandbox:         use_sandbox?
    )
  end

  private

  def use_sandbox?
    ENV["USE_EVERNOTE_SANDBOX"] == "true"
  end

  def validate_evernote_options
    unless evernote_consumer_key.present? &&
      evernote_consumer_secret.present? &&
      evernote_oauth_token.present?
      errors.add(:base, "Evernote ENV variables and a Service are required")
    end
  end

  def evernote_consumer_key
    (config = Devise.omniauth_configs[:evernote]) && config.strategy.consumer_key
  end

  def evernote_consumer_secret
    (config = Devise.omniauth_configs[:evernote]) && config.strategy.consumer_secret
  end

  def evernote_oauth_token
    service && service.token
  end
end
