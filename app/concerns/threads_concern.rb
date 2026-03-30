module ThreadsConcern
  extend ActiveSupport::Concern

  THREADS_DEFAULT_FIELDS = %w[
    id
    media_product_type
    media_type
    media_url
    permalink
    owner
    username
    text
    timestamp
    shortcode
    thumbnail_url
    children
    is_quote_post
    quoted_post
    reposted_post
    alt_text
    link_attachment_url
  ].freeze

  included do
    include Oauthable

    validate :validate_threads_options
    valid_oauth_providers :threads

    gem_dependency_check do
      Devise.omniauth_providers.include?(:threads) &&
        ENV["THREADS_APP_ID"].present? &&
        ENV["THREADS_APP_SECRET"].present?
    end
  end

  def validate_threads_options
    return if service&.token.present?

    errors.add(:base, "Threads access token is required via an authenticated Threads service")
  end

  def threads_access_token
    service&.prepare_request
    service&.token
  end

  def threads_user_id
    service&.options&.[](:user_id)
  end

  def threads_username
    service&.options&.[](:username)
  end

  def threads_account_id
    @threads_account_id ||= threads_user_id.presence || threads_client.account(fields: "id").fetch(:id)
  end

  module ClassMethods
    def threads_dependencies_missing
      if ENV["THREADS_APP_ID"].blank? || ENV["THREADS_APP_SECRET"].blank?
        "## Set THREADS_APP_ID and THREADS_APP_SECRET in your environment to use Threads Agents."
      elsif !Devise.omniauth_providers.include?(:threads)
        "## Configure the Threads OmniAuth provider to use Threads Agents."
      end
    end
  end

  private

  def threads_client
    @threads_client ||= ThreadsApiClient.new(access_token_provider: -> { threads_access_token })
  end
end
