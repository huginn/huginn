module DropboxConcern
  extend ActiveSupport::Concern

  included do
    include Oauthable
    valid_oauth_providers :dropbox
    gem_dependency_check { Devise.omniauth_providers.include?(:dropbox) }
  end

  def dropbox
    DropboxApiClient.new(access_token: oauth_token)
  end

  private

  def oauth_token
    service && service.token
  end
end
