module DropboxConcern
  extend ActiveSupport::Concern

  included do
    include Oauthable
    valid_oauth_providers :dropbox_oauth2
    gem_dependency_check { defined?(Dropbox) && Devise.omniauth_providers.include?(:dropbox) }
  end

  def dropbox
    Dropbox::API::Config.app_key = consumer_key
    Dropbox::API::Config.app_secret = consumer_secret
    Dropbox::API::Config.mode = 'dropbox'
    Dropbox::API::Client.new(token: oauth_token, secret: oauth_token_secret)
  end

  private

  def consumer_key
    (config = Devise.omniauth_configs[:dropbox]) && config.strategy.client_id
  end

  def consumer_secret
    (config = Devise.omniauth_configs[:dropbox]) && config.strategy.client_secret
  end

  def oauth_token
    service && service.token
  end

  def oauth_token_secret
    service && service.secret
  end

end
