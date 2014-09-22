LOADED_OMNIAUTH_STRATEGIES = {
  'twitter'   => defined?(OmniAuth::Strategies::Twitter),
  '37signals' => defined?(OmniAuth::Strategies::ThirtySevenSignals),
  'github'    => defined?(OmniAuth::Strategies::GitHub)
}

def has_oauth_configuration_for?(provider)
  LOADED_OMNIAUTH_STRATEGIES[provider.to_s] && ENV["#{provider.upcase}_OAUTH_KEY"].present? && ENV["#{provider.upcase}_OAUTH_SECRET"].present?
end

Rails.application.config.middleware.use OmniAuth::Builder do
  if has_oauth_configuration_for?('twitter')
    provider 'twitter', ENV['TWITTER_OAUTH_KEY'], ENV['TWITTER_OAUTH_SECRET'], authorize_params: {force_login: 'true', use_authorize: 'true'}
  end

  if has_oauth_configuration_for?('37signals')
    provider '37signals', ENV['THIRTY_SEVEN_SIGNALS_OAUTH_KEY'], ENV['THIRTY_SEVEN_SIGNALS_OAUTH_SECRET']
  end

  if has_oauth_configuration_for?('github')
    provider 'github', ENV['GITHUB_OAUTH_KEY'], ENV['GITHUB_OAUTH_SECRET']
  end
end
