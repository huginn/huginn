# Instance-wide egress proxy for outbound HTTP(S) requests, configured with
# the OUTBOUND_PROXY environment variable.  When set, every HTTP client that
# Huginn builds is routed through it and Agents may not choose a proxy of
# their own.  Point it at a proxy that refuses private and link-local
# destinations to keep Agents from reaching internal services.
module OutboundProxy
  class ConfigurationError < StandardError; end

  module_function

  def url
    value = ENV['OUTBOUND_PROXY'].presence or return nil

    uri = URI.parse(value)
    unless uri.is_a?(URI::HTTP) && uri.host.present?
      raise ConfigurationError, "OUTBOUND_PROXY must be an http:// or https:// URL: #{value.inspect}"
    end

    uri.to_s
  rescue URI::InvalidURIError
    raise ConfigurationError, "OUTBOUND_PROXY must be an http:// or https:// URL: #{value.inspect}"
  end

  def enforced?
    !url.nil?
  end

  # Applies the proxy to clients that do not set one explicitly.
  def configure!
    proxy = url
    Faraday.default_connection_options.proxy = proxy
    Typhoeus::Config.proxy = proxy if defined?(Typhoeus)
  end
end
