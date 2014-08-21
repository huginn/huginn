module ServiceHelper
  def has_oauth_configuration_for(provider)
    ENV["#{provider.upcase}_OAUTH_KEY"].present? && ENV["#{provider.upcase}_OAUTH_SECRET"].present?
  end
end