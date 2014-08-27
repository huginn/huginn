module TwitterConcern
  extend ActiveSupport::Concern
  include Oauthable

  included do
    validate :validate_twitter_options
    valid_oauth_providers :twitter
  end

  def validate_twitter_options
    unless twitter_consumer_key.present? &&
      twitter_consumer_secret.present? &&
      twitter_oauth_token.present? &&
      twitter_oauth_token_secret.present?
      errors.add(:base, "Twitter consumer_key, consumer_secret, oauth_token, and oauth_token_secret are required to authenticate with the Twitter API.  You can provide these as options to this Agent, or as Credentials with the same names, but starting with 'twitter_'.")
    end
  end

  def twitter_consumer_key
    ENV['TWITTER_OAUTH_KEY']
  end

  def twitter_consumer_secret
    ENV['TWITTER_OAUTH_SECRET']
  end

  def twitter_oauth_token
    service.token
  end

  def twitter_oauth_token_secret
    service.secret
  end

  def twitter
    Twitter::REST::Client.new do |config|
      config.consumer_key = twitter_consumer_key
      config.consumer_secret = twitter_consumer_secret
      config.access_token = twitter_oauth_token
      config.access_token_secret = twitter_oauth_token_secret
    end
  end
end