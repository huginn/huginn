module TwitterConcern
  extend ActiveSupport::Concern

  included do
    include Oauthable

    validate :validate_twitter_options
    valid_oauth_providers :twitter

    gem_dependency_check { defined?(Twitter) && Devise.omniauth_providers.include?(:twitter) && ENV['TWITTER_OAUTH_KEY'].present? && ENV['TWITTER_OAUTH_SECRET'].present? }
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
    (config = Devise.omniauth_configs[:twitter]) && config.strategy.consumer_key
  end

  def twitter_consumer_secret
    (config = Devise.omniauth_configs[:twitter]) && config.strategy.consumer_secret
  end

  def twitter_oauth_token
    service && service.token
  end

  def twitter_oauth_token_secret
    service && service.secret
  end

  def twitter
    Twitter::REST::Client.new do |config|
      config.consumer_key = twitter_consumer_key
      config.consumer_secret = twitter_consumer_secret
      config.access_token = twitter_oauth_token
      config.access_token_secret = twitter_oauth_token_secret
    end
  end

  module ClassMethods
    def twitter_dependencies_missing
      if ENV['TWITTER_OAUTH_KEY'].blank? || ENV['TWITTER_OAUTH_SECRET'].blank?
        "## Set TWITTER_OAUTH_KEY and TWITTER_OAUTH_SECRET in your environment to use Twitter Agents."
      elsif !defined?(Twitter) || !Devise.omniauth_providers.include?(:twitter)
        "## Include the `twitter`, `omniauth-twitter`, and `cantino-twitter-stream` gems in your Gemfile to use Twitter Agents."
      end
    end
  end
end
