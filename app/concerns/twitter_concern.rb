module TwitterConcern
  extend ActiveSupport::Concern

  included do
    validate :twitter_consumer_key_present
    validate :twitter_consumer_secret_present
    validate :twitter_oauth_token_present
    validate :twitter_oauth_token_secret_present
    validate :valid_credentials
  end

  def twitter_consumer_key
    @twitter_consumer_key ||= options['consumer_key'].presence || credential('twitter_consumer_key')
  end

  def twitter_consumer_secret
    @twitter_consumer_secret ||= options['consumer_secret'].presence || credential('twitter_consumer_secret')
  end

  def twitter_oauth_token
    @twitter_oauth_token ||= options['oauth_token'].presence || options['access_key'].presence || credential('twitter_oauth_token')
  end

  def twitter_oauth_token_secret
    @twitter_oauth_token_secret ||= options['oauth_token_secret'].presence || options['access_secret'].presence || credential('twitter_oauth_token_secret')
  end

  def twitter
    @twitter ||= Twitter::REST::Client.new do |config|
      config.consumer_key = twitter_consumer_key
      config.consumer_secret = twitter_consumer_secret
      config.access_token = twitter_oauth_token
      config.access_token_secret = twitter_oauth_token_secret
    end
  end


  private
    def twitter_consumer_key_present
      if twitter_consumer_key.nil?
        errors.add(:base, "Consumer Key cannot be blank")
      end
    end
    
    def twitter_consumer_secret_present
      if twitter_consumer_secret.nil?
        errors.add(:base, "Consumer secret cannot be blank")
      end
    end

    def twitter_oauth_token_present      
      if twitter_oauth_token.nil?
        errors.add(:base, "Oauth token cannot be blank")
      end
    end

    def twitter_oauth_token_secret_present
      if twitter_oauth_token_secret.nil?
        errors.add(:base, "Oauth secret cannot be blank")
      end
    end
    
    def valid_credentials
    #   twitter.verify_credentials.present?
    # rescue Twitter::Error
    #   errors.add(:base, "Twitter credentials are invalid, a connection could not be established")
    #   false
    end
end