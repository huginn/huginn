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
      sandbox: false
    )
  end

  private

  def validate_evernote_options
    unless evernote_consumer_key.present? &&
      evernote_consumer_secret.present? &&
      evernote_oauth_token.present?
      errors.add(:base, "Evernote consumer_key, consumer_secret, oauth_token, and oauth_token_secret are required to authenticate with the Twitter API.  You can provide these as options to this Agent, or as Credentials with the same names, but starting with 'evernote_'.")
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

  def evernote_oauth_token_secret
    service && service.secret
  end
end
