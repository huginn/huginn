module TwitterConcern
  extend ActiveSupport::Concern

  included do
    validate :validate_twitter_options
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
    options['consumer_key'].presence || credential('twitter_consumer_key')
  end

  def twitter_consumer_secret
    options['consumer_secret'].presence || credential('twitter_consumer_secret')
  end

  def twitter_oauth_token
    options['oauth_token'].presence || options['access_key'].presence || credential('twitter_oauth_token')
  end

  def twitter_oauth_token_secret
    options['oauth_token_secret'].presence || options['access_secret'].presence || credential('twitter_oauth_token_secret')
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