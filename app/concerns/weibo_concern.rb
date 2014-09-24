module WeiboConcern
  extend ActiveSupport::Concern

  included do
    gem_dependency_check { defined?(WeiboOAuth2) }

    self.validate :validate_weibo_options
  end

  def validate_weibo_options
    unless options['app_key'].present? &&
        options['app_secret'].present? &&
        options['access_token'].present?
        errors.add(:base, "app_key, app_secret and access_token are required")
    end
  end

  def weibo_client
    unless @weibo_client
      WeiboOAuth2::Config.api_key = options['app_key'] # WEIBO_APP_KEY
      WeiboOAuth2::Config.api_secret = options['app_secret'] # WEIBO_APP_SECRET
      @weibo_client = WeiboOAuth2::Client.new
      @weibo_client.get_token_from_hash :access_token => options['access_token']
    end
    @weibo_client
  end
end
