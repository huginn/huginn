Rails.application.config.to_prepare do
  OutboundProxy.configure!
end
