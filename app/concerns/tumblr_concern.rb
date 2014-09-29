module TumblrConcern
  extend ActiveSupport::Concern

  included do
    include Oauthable

    valid_oauth_providers :tumblr
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