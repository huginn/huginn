class Service < ActiveRecord::Base
  serialize :options, coder: YAML, type: Hash

  belongs_to :user, inverse_of: :services
  has_many :agents, inverse_of: :service

  validates_presence_of :user_id, :provider, :name, :token

  before_destroy :disable_agents

  scope :available_to_user, lambda { |user| where("services.user_id = ? or services.global = true", user.id) }
  scope :by_name, lambda { |dir = 'desc'| order("services.name #{dir}") }

  def disable_agents(conditions = {})
    agents.where.not(conditions[:where_not] || {}).each do |agent|
      agent.service_id = nil
      agent.disabled = true
      agent.save!(validate: false)
    end
  end

  def toggle_availability!
    disable_agents(where_not: { user_id: self.user_id }) if global
    self.global = !self.global
    self.save!
  end

  def prepare_request
    if expires_at && Time.now > expires_at
      refresh_token!
    end
  end

  def refresh_token_parameters
    {
      grant_type: 'refresh_token',
      client_id: oauth_key,
      client_secret: oauth_secret,
      refresh_token:
    }
  end

  def refresh_token!
    response =
      if provider == "threads"
        self.class.threads_connection.get("refresh_access_token", {
          grant_type: "th_refresh_token",
          access_token: token
        })
      else
        self.class.oauth_connection.post(endpoint.to_s, refresh_token_parameters)
      end
    data = response.body
    update(expires_at: Time.current + data['expires_in'].to_i, token: data['access_token'],
           refresh_token: data['refresh_token'].presence || refresh_token)
  end

  def endpoint
    client_options = Devise.omniauth_configs[provider.to_sym].strategy_class.default_options['client_options']
    URI.join(client_options['site'], client_options['token_url'])
  end

  def oauth_key
    (config = Devise.omniauth_configs[provider.to_sym]) && config.args[0]
  end

  def oauth_secret
    (config = Devise.omniauth_configs[provider.to_sym]) && config.args[1]
  end

  def self.initialize_or_update_via_omniauth(omniauth)
    options = get_options(omniauth)
    credentials = get_credentials(omniauth)

    find_or_initialize_by(provider: omniauth['provider'], uid: omniauth['uid'].to_s).tap do |service|
      service.attributes = {
        token: credentials[:token],
        secret: credentials[:secret],
        name: options[:name],
        refresh_token: credentials[:refresh_token],
        expires_at: credentials[:expires_at],
        options:
      }
    end
  end

  def self.register_options_provider(provider_name, &block)
    option_providers[provider_name] = block
  end

  def self.get_options(omniauth)
    option_providers.fetch(omniauth['provider'], option_providers['default']).call(omniauth)
  end

  def self.register_credentials_provider(provider_name, &block)
    credential_providers[provider_name] = block
  end

  def self.get_credentials(omniauth)
    credential_providers.fetch(omniauth['provider'], credential_providers['default']).call(omniauth)
  end

  def self.oauth_connection
    @oauth_connection ||= Faraday.new do |builder|
      builder.request :url_encoded
      builder.response :json
      builder.adapter Faraday.default_adapter
    end
  end

  def self.threads_connection
    @threads_connection ||= Faraday.new(url: "https://graph.threads.net") do |builder|
      builder.request :url_encoded
      builder.response :json
      builder.adapter Faraday.default_adapter
    end
  end

  @@option_providers = HashWithIndifferentAccess.new
  cattr_reader :option_providers
  @@credential_providers = HashWithIndifferentAccess.new
  cattr_reader :credential_providers

  register_options_provider('default') do |omniauth|
    { name: omniauth['info']['nickname'] || omniauth['info']['name'] }
  end

  register_options_provider('google') do |omniauth|
    {
      email: omniauth['info']['email'],
      name: "#{omniauth['info']['name']} <#{omniauth['info']['email']}>"
    }
  end

  register_options_provider('threads') do |omniauth|
    raw_info = omniauth.dig('extra', 'raw_info') || {}
    username = omniauth.dig('info', 'nickname').presence || raw_info['username'].presence || omniauth['uid']

    {
      user_id: raw_info['id'] || omniauth['uid'],
      username:,
      name: username
    }
  end

  register_credentials_provider('default') do |omniauth|
    {
      token: omniauth.dig('credentials', 'token'),
      secret: omniauth.dig('credentials', 'secret'),
      refresh_token: omniauth.dig('credentials', 'refresh_token'),
      expires_at: omniauth.dig('credentials', 'expires_at') && Time.at(omniauth['credentials']['expires_at'])
    }
  end

  register_credentials_provider('threads') do |omniauth|
    credentials = credential_providers['default'].call(omniauth)
    token = credentials[:token]
    secret = (config = Devise.omniauth_configs[:threads]) && config.args[1]

    if token.present? && secret.present?
      response = threads_connection.get("access_token", {
        grant_type: "th_exchange_token",
        client_secret: secret,
        access_token: token
      })
      data = response.body

      if response.success? && data['access_token'].present?
        credentials[:token] = data['access_token']
        credentials[:expires_at] = Time.current + data['expires_in'].to_i
      end
    end

    credentials
  end
end
