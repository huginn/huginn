# frozen_string_literal: true

# Shared Tumblr OAuth helpers for Tumblr agents.
module TumblrConcern
  extend ActiveSupport::Concern

  included do
    include Oauthable

    valid_oauth_providers :tumblr
  end

  def tumblr_consumer_key
    ENV["TUMBLR_OAUTH_KEY"]
  end

  def tumblr_consumer_secret
    ENV["TUMBLR_OAUTH_SECRET"]
  end

  def tumblr_oauth_token
    service&.token
  end

  def tumblr_oauth_token_secret
    service&.secret
  end

  def tumblr
    TumblrApiClient.new(
      consumer_key: tumblr_consumer_key,
      consumer_secret: tumblr_consumer_secret,
      oauth_token: tumblr_oauth_token,
      oauth_token_secret: tumblr_oauth_token_secret
    )
  end

  # Dependency messaging for agent descriptions.
  module ClassMethods
    def tumblr_dependencies_missing
      if ENV["TUMBLR_OAUTH_KEY"].blank? || ENV["TUMBLR_OAUTH_SECRET"].blank?
        "## Set TUMBLR_OAUTH_KEY and TUMBLR_OAUTH_SECRET in your environment to use Tumblr Agents."
      elsif !Devise.omniauth_providers.include?(:tumblr)
        "## Tumblr OAuth is not configured correctly.  Check the Tumblr strategy load and your Devise OmniAuth setup."
      end
    end
  end
end
