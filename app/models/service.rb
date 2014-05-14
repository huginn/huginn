class Service < ActiveRecord::Base
  attr_accessible :provider, :name, :token, :secret, :refresh_token, :expires_at, :global, :options

  serialize :options, Hash

  belongs_to :user

  validates_presence_of :user_id, :provider, :name, :token

  def toggle_availability!
    self.global = !self.global
    self.save!
  end

  def prepare_request
    if self.expires_at && Time.now > self.expires_at
      self.refresh_token!
    end
  end

  def refresh_token!
    response = HTTParty.post(endpoint, query: {
                  type:          'refresh',
                  client_id:     ENV["#{self.provider.upcase}_OAUTH_KEY"],
                  client_secret: ENV["#{self.provider.upcase}_OAUTH_SECRET"],
                  refresh_token: self.refresh_token
    })
    data = JSON.parse(response.body)
    self.update(expires_at: Time.now + data['expires_in'], token: data['access_token'], refresh_token: data['refresh_token'].presence || self.refresh_token)
  end

  def self.initialize_or_update_via_omniauth(omniauth)
    case omniauth['provider']
    when 'twitter'
      find_or_initialize_by(provider: omniauth['provider'], name: omniauth['info']['nickname']).tap do |service|
        service.assign_attributes(token: omniauth['credentials']['token'], secret: omniauth['credentials']['secret'])
      end
    when 'github'
      find_or_initialize_by(provider: omniauth['provider'], name: omniauth['info']['nickname']).tap do |service|
        service.assign_attributes(token: omniauth['credentials']['token'])
      end
    when '37signals'
      find_or_initialize_by(provider: omniauth['provider'], name: omniauth['info']['name']).tap do |service|
        service.assign_attributes(token: omniauth['credentials']['token'],
                                  refresh_token: omniauth['credentials']['refresh_token'],
                                  expires_at: Time.at(omniauth['credentials']['expires_at']),
                                  options: {user_id: omniauth['extra']['accounts'][0]['id']})
      end
    else
      false
    end
  end

  private
  def endpoint
    client_options = "OmniAuth::Strategies::#{OmniAuth::Utils.camelize(self.provider)}".constantize.default_options['client_options']
    URI.join(client_options['site'], client_options['token_url'])
  end
end