require 'pp'
Rails.application.config.to_prepare do
  HuginnAgent.require!
end
