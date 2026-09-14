Rails.application.config.to_prepare do
  NetworkTimeout.configure!
end
