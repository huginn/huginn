module TumblrConcern
  extend ActiveSupport::Concern

  included do
    include Oauthable

    validate :validate_tumblr_options
    valid_oauth_providers :tumblr
  end

  def validate_tumblr_options
    unless tumblr_consumer_key.present? &&
      tumblr_consumer_secret.present? &&
      tumblr_oauth_token.present? &&
      tumblr_oauth_token_secret.present?
      errors.add(:base, "Tumblr consumer_key, consumer_secret, oauth_token, and oauth_token_secret are required to authenticate with the Tumblr API.  You can provide these as options to this Agent, or as Credentials with the same names, but starting with 'tumblr_'.")
    end
  end

  def tumblr_consumer_key
    ENV['TUMBLR_OAUTH_KEY']
  end

  def tumblr_consumer_secret
    ENV['TUMBLR_OAUTH_SECRET']
  end

  def tumblr_oauth_token
    service.token
  end

  def tumblr_oauth_token_secret
    service.secret
  end

  def tumblr
    Tumblr.configure do |config|
      config.consumer_key = tumblr_consumer_key
      config.consumer_secret = tumblr_consumer_secret
      config.oauth_token = tumblr_oauth_token
      config.oauth_token_secret = tumblr_oauth_token_secret
    end
    
    Tumblr::Client.new
  end
end