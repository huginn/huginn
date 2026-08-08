require 'ipaddr'
require 'net/http'
require 'openssl'
require 'resolv'
require 'uri'

class SafeScenarioUrlFetcher
  Error = Class.new(StandardError)

  MAX_REDIRECTS = 5
  MAX_RESPONSE_BYTES = 2 * 1024 * 1024
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10
  USER_AGENT = 'Huginn ScenarioImport'.freeze

  BLOCKED_IP_RANGES = [
    IPAddr.new('0.0.0.0/8'),
    IPAddr.new('10.0.0.0/8'),
    IPAddr.new('100.64.0.0/10'),
    IPAddr.new('127.0.0.0/8'),
    IPAddr.new('169.254.0.0/16'),
    IPAddr.new('172.16.0.0/12'),
    IPAddr.new('192.0.0.0/24'),
    IPAddr.new('192.0.2.0/24'),
    IPAddr.new('192.168.0.0/16'),
    IPAddr.new('198.18.0.0/15'),
    IPAddr.new('198.51.100.0/24'),
    IPAddr.new('203.0.113.0/24'),
    IPAddr.new('224.0.0.0/4'),
    IPAddr.new('240.0.0.0/4'),
    IPAddr.new('::/128'),
    IPAddr.new('::1/128'),
    IPAddr.new('::ffff:0:0/96'),
    IPAddr.new('64:ff9b::/96'),
    IPAddr.new('100::/64'),
    IPAddr.new('2001::/23'),
    IPAddr.new('2001:2::/48'),
    IPAddr.new('2001:db8::/32'),
    IPAddr.new('fc00::/7'),
    IPAddr.new('fe80::/10'),
    IPAddr.new('ff00::/8')
  ].freeze

  class << self
    def fetch(url)
      new(url).fetch
    end
  end

  def initialize(url)
    @url = url.to_s
  end

  def fetch
    fetch_uri(parse_uri(@url), MAX_REDIRECTS)
  end

  private

  def fetch_uri(uri, redirects_remaining)
    validate_uri!(uri)
    ip = resolve_public_ip!(uri.host)
    response, body = request(uri, ip)

    if redirect?(response)
      raise Error, 'redirect limit exceeded' if redirects_remaining <= 0

      location = response['location'].to_s
      raise Error, 'redirect response missing location' if location.empty?

      return fetch_uri(parse_uri(location, uri), redirects_remaining - 1)
    end

    raise Error, "remote server returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    body
  rescue Timeout::Error, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
    raise Error, "could not fetch URL: #{e.message}"
  end

  def parse_uri(value, base = nil)
    uri = URI.parse(value.to_s)
    uri = base + uri if base && uri.relative?
    uri
  rescue URI::InvalidURIError
    raise Error, 'appears to be invalid'
  end

  def validate_uri!(uri)
    raise Error, 'appears to be invalid' unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    raise Error, 'must use http or https' unless %w[http https].include?(uri.scheme)
    raise Error, 'must include a host' if uri.host.to_s.empty?
    raise Error, 'must not include credentials' unless uri.userinfo.nil?
    raise Error, 'must not include a fragment' unless uri.fragment.nil?
  end

  def resolve_public_ip!(host)
    addresses = Resolv.getaddresses(host)
    raise Error, 'host could not be resolved' if addresses.empty?

    addresses.each do |address|
      ip = IPAddr.new(address)
      raise Error, 'URL host resolves to a blocked address' if blocked_ip?(ip)
    rescue IPAddr::InvalidAddressError
      raise Error, 'host resolved to an invalid address'
    end

    addresses.first
  rescue Resolv::ResolvError
    raise Error, 'host could not be resolved'
  end

  def blocked_ip?(ip)
    BLOCKED_IP_RANGES.any? { |range| range.include?(ip) }
  end

  def request(uri, ip)
    Net::HTTP.start(
      uri.host,
      uri.port,
      nil,
      nil,
      nil,
      nil,
      use_ssl: uri.scheme == 'https',
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT,
      ipaddr: ip
    ) do |http|
      request_uri = uri.request_uri
      request_uri = '/' if request_uri.empty?
      request = Net::HTTP::Get.new(request_uri)
      request['User-Agent'] = USER_AGENT
      response_body = String.new

      response = http.request(request) do |res|
        res.read_body do |chunk|
          response_body << chunk
          raise Error, 'response body is too large' if response_body.bytesize > MAX_RESPONSE_BYTES
        end
      end

      [response, response_body]
    end
  end

  def redirect?(response)
    response.is_a?(Net::HTTPRedirection)
  end
end
