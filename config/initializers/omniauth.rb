OMNIAUTH_PROVIDERS = {}.tap { |providers|
  if defined?(OmniAuth::Strategies::Twitter) &&
     (key = ENV["TWITTER_OAUTH_KEY"]).present? &&
     (secret = ENV["TWITTER_OAUTH_SECRET"]).present?
    providers['twitter'] = {
      omniauth_params: [key, secret, authorize_params: {force_login: 'true', use_authorize: 'true'}]
    }
  end

  if defined?(OmniAuth::Strategies::ThirtySevenSignals) &&
     (key = ENV["THIRTY_SEVEN_SIGNALS_OAUTH_KEY"]).present? &&
     (secret = ENV["THIRTY_SEVEN_SIGNALS_OAUTH_SECRET"]).present?
    providers['37signals'] = {
      omniauth_params: [key, secret]
    }
  end

  if defined?(OmniAuth::Strategies::GitHub) &&
     (key = ENV["GITHUB_OAUTH_KEY"]).present? &&
     (secret = ENV["GITHUB_OAUTH_SECRET"]).present?
    providers['github'] = {
      omniauth_params: [key, secret]
    }
  end
}

def has_oauth_configuration_for?(provider)
  OMNIAUTH_PROVIDERS.key?(provider.to_s)
end

Rails.application.config.middleware.use OmniAuth::Builder do
  OMNIAUTH_PROVIDERS.each { |name, config|
    provider name, *config[:omniauth_params]
  }
end
