module Oauthable
  extend ActiveSupport::Concern

  included do |base|
    attr_accessible :service_id
    validates_presence_of :service_id
    self.class_variable_set(:@@valid_oauth_providers, :all)
  end

  def oauthable?
    true
  end

  def valid_services(current_user)
    if valid_oauth_providers == :all
      current_user.available_services
    else
      current_user.available_services.where(provider: valid_oauth_providers)
    end
  end

  def valid_oauth_providers
    self.class.class_variable_get(:@@valid_oauth_providers)
  end

  module ClassMethods
    def valid_oauth_providers(*providers)
      self.class_variable_set(:@@valid_oauth_providers, providers)
    end
  end
end
