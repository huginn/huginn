module TwitterConcern
  extend ActiveSupport::Concern

  included do
    self.validate :validate_twitter_options
    self.after_initialize :configure_twitter
  end

  def validate_twitter_options
    unless options[:consumer_key].present? &&
      options[:consumer_secret].present? &&
      options[:oauth_token].present? &&
      options[:oauth_token_secret].present?
      errors.add(:base, "consumer_key, consumer_secret, oauth_token and oauth_token_secret are required to authenticate with the Twitter API")
    end
  end

  def configure_twitter
    Twitter.configure do |config|
      config.consumer_key = options[:consumer_key]
      config.consumer_secret = options[:consumer_secret]
      config.oauth_token = options[:oauth_token]
      config.oauth_token_secret = options[:oauth_token_secret]
    end
  end

  module ClassMethods

  end
end