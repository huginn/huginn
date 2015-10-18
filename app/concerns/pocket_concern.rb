module PocketConcern
  extend ActiveSupport::Concern

  included do
    include Oauthable

    validate :validate_pocket_options
    valid_oauth_providers :pocket

    gem_dependency_check { defined?(Twitter) && Devise.omniauth_providers.include?(:pocket) && ENV['POCKET_OAUTH_KEY'].present? }
  end

  def validate_pocket_options
    unless pocket_consumer_key.present? 
      errors.add(:base, "Pocket consumer_key is required to authenticate with the Pocket API.")
    end
  end

  def pocket_consumer_key
    (config = Devise.omniauth_configs[:pocket]) && config.strategy.consumer_key
  end

  def pocket
    Pocket.configure do |config|
      config.consumer_key = 'pocket_consumer_key
    end
  end

  module ClassMethods
    def pocket_dependencies_missing
      if ENV['POCKET_OAUTH_KEY'].blank?
        "## Set POCKET_OAUTH_KEY in your environment to use Pocket Agents."
      elsif !defined?(Twitter) || !Devise.omniauth_providers.include?(:pocket)
        "## Include the `twitter`, `omniauth-twitter`, and `cantino-twitter-stream` gems in your Gemfile to use Twitter Agents."
      end
    end
  end
end
