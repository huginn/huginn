module RaindropConcern
  extend ActiveSupport::Concern

  included do
    include Oauthable

    validate :validate_raindrop_options
    valid_oauth_providers :raindrop

    gem_dependency_check do
      Devise.omniauth_providers.include?(:raindrop) &&
        raindrop_client_id.present? &&
        raindrop_client_secret.present?
    end
  end

  def validate_raindrop_options
    return if service&.token.present?

    errors.add(:base, "Raindrop access token is required via an authenticated Raindrop service")
  end

  def raindrop_access_token
    service&.prepare_request
    service&.token
  end

  module ClassMethods
    def raindrop_client_id
      ENV["RAINDROP_CLIENT_ID"].presence
    end

    def raindrop_client_secret
      ENV["RAINDROP_CLIENT_SECRET"].presence
    end

    def raindrop_dependencies_missing
      case
      when raindrop_client_id.blank? || raindrop_client_secret.blank?
        "## Set RAINDROP_CLIENT_ID and RAINDROP_CLIENT_SECRET in your environment to use Raindrop Agents."
      when !Devise.omniauth_providers.include?(:raindrop)
        "## Configure the Raindrop OmniAuth provider to use Raindrop Agents."
      end
    end
  end

  private

  def raindrop_client
    @raindrop_client ||= RaindropApiClient.new(access_token_provider: -> { raindrop_access_token })
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
