# Selects per-Agent proxies while preserving instance-wide enforcement.
module AgentProxyConcern
  extend ActiveSupport::Concern

  included do
    validate :validate_proxy_options
  end

  def request_proxy
    if (proxy = OutboundProxy.url)
      return proxy
    end

    if boolify(options["use_agent_proxy"])
      OutboundProxy.agent_url or raise OutboundProxy::ConfigurationError, "use_agent_proxy requires AGENT_PROXY"
    else
      interpolated["proxy"].presence
    end
  end

  private

  def validate_proxy_options
    if options["proxy"].present?
      errors.add(:base, "proxy must be a string") unless options["proxy"].is_a?(String)
      if OutboundProxy.enforced?
        errors.add(:base,
                   "proxy cannot be set because outbound requests of this Huginn instance go through OUTBOUND_PROXY")
      end
      if boolify(options["use_agent_proxy"])
        errors.add(:base, "proxy cannot be combined with use_agent_proxy")
      end
    end

    if option_provided?(options["use_agent_proxy"]) && boolify(options["use_agent_proxy"]).nil?
      errors.add(:base, "if provided, use_agent_proxy must be true or false")
    end

    if boolify(options["use_agent_proxy"]) && !OutboundProxy.enforced? && !OutboundProxy.agent_url
      errors.add(:base, "use_agent_proxy requires AGENT_PROXY")
    end
  end
end
