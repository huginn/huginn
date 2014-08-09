Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter, ENV['TWITTER_OAUTH_KEY'], ENV['TWITTER_OAUTH_SECRET'], authorize_params: {force_login: 'true', use_authorize: 'true'}
  provider '37signals', ENV['THIRTY_SEVEN_SIGNALS_OAUTH_KEY'], ENV['THIRTY_SEVEN_SIGNALS_OAUTH_SECRET']
  provider :github, ENV['GITHUB_OAUTH_KEY'], ENV['GITHUB_OAUTH_SECRET']
end
