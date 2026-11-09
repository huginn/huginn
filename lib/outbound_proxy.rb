require "httparty"
require "net/http"

# Instance-wide egress proxy for outbound HTTP(S) requests, configured with
# the OUTBOUND_PROXY environment variable.  When set, every HTTP client that
# Huginn builds is routed through it and Agents may not choose a proxy of
# their own.  Point it at a proxy that refuses private and link-local
# destinations to keep Agents from reaching internal services.
module OutboundProxy
  class ConfigurationError < StandardError; end

  class HttpartyConnectionAdapter < HTTParty::ConnectionAdapter
    def connection
      OutboundProxy.configure_net_http(super)
    end
  end

  module_function

  def url
    proxy_url("OUTBOUND_PROXY")
  end

  def agent_url
    proxy_url("AGENT_PROXY")
  end

  def proxy_url(variable)
    value = ENV[variable].presence or return nil

    uri = URI.parse(value)
    unless uri.is_a?(URI::HTTP) && uri.host.present?
      raise ConfigurationError, "#{variable} must be an http:// or https:// URL: #{value.inspect}"
    end

    uri.to_s
  rescue URI::InvalidURIError
    raise ConfigurationError, "#{variable} must be an http:// or https:// URL: #{value.inspect}"
  end

  def enforced?
    !url.nil?
  end

  # Applies the proxy to clients that do not set one explicitly.
  def configure!
    proxy = url
    agent_url # Validate the opt-in proxy without applying it globally.
    Faraday.default_connection_options.proxy = proxy
    Typhoeus::Config.proxy = proxy if defined?(Typhoeus)

    clients = [HTTParty::Basement]
    clients << HTTMultiParty::Basement if defined?(HTTMultiParty)
    clients.concat([HipChat::Client, HipChat::Room, HipChat::User]) if defined?(HipChat)
    clients.each do |client|
      client.connection_adapter(HttpartyConnectionAdapter)
    end
  end

  def configure_net_http(http)
    if (proxy = url)
      uri = URI.parse(proxy)
      http.proxy_from_env = false
      http.proxy_address = uri.hostname
      http.proxy_port = uri.port
      http.proxy_user = uri.user && URI::DEFAULT_PARSER.unescape(uri.user)
      http.proxy_pass = uri.password && URI::DEFAULT_PARSER.unescape(uri.password)
      http.proxy_use_ssl = uri.scheme == "https"
    end
    http
  end

  def open_uri_options
    proxy = url or return {}
    uri = URI.parse(proxy)
    if uri.userinfo
      user = URI::DEFAULT_PARSER.unescape(uri.user.to_s)
      password = URI::DEFAULT_PARSER.unescape(uri.password.to_s)
      uri.user = nil
      { proxy_http_basic_authentication: [uri.to_s, user, password] }
    else
      { proxy: }
    end
  end
end
