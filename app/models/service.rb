class Service < ActiveRecord::Base
  serialize :options, Hash

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
    response = HTTParty.post(endpoint, query: refresh_token_parameters)
    data = JSON.parse(response.body)
    update(expires_at: Time.now + data['expires_in'], token: data['access_token'],
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

    find_or_initialize_by(provider: omniauth['provider'], uid: omniauth['uid'].to_s).tap do |service|
      service.attributes = {
        token: omniauth['credentials']['token'],
        secret: omniauth['credentials']['secret'],
        name: options[:name],
        refresh_token: omniauth['credentials']['refresh_token'],
        expires_at: omniauth['credentials']['expires_at'] && Time.at(omniauth['credentials']['expires_at']),
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

  @@option_providers = HashWithIndifferentAccess.new
  cattr_reader :option_providers

  register_options_provider('default') do |omniauth|
    { name: omniauth['info']['nickname'] || omniauth['info']['name'] }
  end

  register_options_provider('google') do |omniauth|
    {
      email: omniauth['info']['email'],
      name: "#{omniauth['info']['name']} <#{omniauth['info']['email']}>"
    }
  end
end
