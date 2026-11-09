require 'rails_helper'
require 'open-uri'
require 'socket'
require 'timeout'

describe OutboundProxy do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('AGENT_PROXY').and_return(nil)
  end

  def with_outbound_proxy(value)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('OUTBOUND_PROXY').and_return(value)
  end

  after do
    with_outbound_proxy(nil)
    allow(ENV).to receive(:[]).with('AGENT_PROXY').and_return(nil)
    OutboundProxy.configure!
  end

  describe '.url' do
    it 'is nil when OUTBOUND_PROXY is not set' do
      with_outbound_proxy(nil)
      expect(OutboundProxy.url).to be_nil
      expect(OutboundProxy).not_to be_enforced
    end

    it 'returns the configured proxy URL' do
      with_outbound_proxy('http://smokescreen:4750')
      expect(OutboundProxy.url).to eq('http://smokescreen:4750')
      expect(OutboundProxy).to be_enforced
    end

    it 'rejects values that are not http(s) URLs' do
      ['smokescreen:4750', 'socks5://smokescreen:1080', 'http://', 'not a url'].each do |value|
        with_outbound_proxy(value)
        expect { OutboundProxy.url }.to raise_error(OutboundProxy::ConfigurationError)
      end
    end
  end

  describe '.agent_url' do
    it 'is nil when AGENT_PROXY is not set' do
      expect(OutboundProxy.agent_url).to be_nil
    end

    it 'accepts an HTTP proxy URL independently of OUTBOUND_PROXY' do
      with_outbound_proxy(nil)
      allow(ENV).to receive(:[]).with('AGENT_PROXY').and_return('http://optional-proxy:4750')
      expect(OutboundProxy.agent_url).to eq('http://optional-proxy:4750')
      expect(OutboundProxy).not_to be_enforced
      OutboundProxy.configure!
      expect(Faraday.new('http://example.com/').proxy).to be_nil
      expect(Typhoeus::Config.proxy).to be_nil
    end

    it 'rejects a malformed AGENT_PROXY at startup' do
      allow(ENV).to receive(:[]).with('AGENT_PROXY').and_return('not a url')
      expect { OutboundProxy.configure! }.to raise_error(OutboundProxy::ConfigurationError, /AGENT_PROXY/)
    end
  end

  describe '.configure!' do
    it 'applies the proxy to Faraday and Typhoeus defaults' do
      with_outbound_proxy('http://smokescreen:4750')
      OutboundProxy.configure!
      expect(Faraday.new('http://example.com/').proxy.uri.to_s).to eq('http://smokescreen:4750')
      expect(Typhoeus::Config.proxy).to eq('http://smokescreen:4750')
    end

    it 'clears the defaults when OUTBOUND_PROXY is not set' do
      with_outbound_proxy(nil)
      OutboundProxy.configure!
      expect(Faraday.new('http://example.com/').proxy).to be_nil
      expect(Typhoeus::Config.proxy).to be_nil
    end

    it 'routes HTTParty connections through the enforced proxy' do
      with_outbound_proxy('http://smokescreen:4750')
      OutboundProxy.configure!
      http = HTTParty::Basement.connection_adapter.call(URI('http://127.0.0.1/'), http_proxyaddr: nil)

      expect(http.proxy_address).to eq('smokescreen')
      expect(http.proxy_port).to eq(4750)
      expect(http).not_to be_proxy_from_env
    end

    it 'configures HTTParty clients that copied defaults before initialization' do
      OutboundProxy.configure!

      clients = [HTTMultiParty::Basement, HipChat::Client, HipChat::Room, HipChat::User]
      expect(clients.map(&:connection_adapter)).to all(eq(OutboundProxy::HttpartyConnectionAdapter))
    end
  end

  describe '.configure_net_http' do
    it 'overrides an existing proxy and its credentials' do
      with_outbound_proxy('http://smokescreen:4750')
      http = Net::HTTP.new('127.0.0.1', 80, 'other-proxy', 3128, 'old-user', 'old-password')

      expect(OutboundProxy.configure_net_http(http)).to equal(http)
      expect(http.proxy_address).to eq('smokescreen')
      expect(http.proxy_port).to eq(4750)
      expect(http.proxy_user).to be_nil
      expect(http.proxy_pass).to be_nil
      expect(http).not_to be_proxy_from_env
    end

    it 'supports an authenticated HTTPS proxy with escaped credentials and an IPv6 host' do
      with_outbound_proxy('https://proxy%2Buser:p%40ss@[::1]:4750')
      http = OutboundProxy.configure_net_http(Net::HTTP.new('example.com'))

      expect(http.proxy_address).to eq('::1')
      expect(http.proxy_port).to eq(4750)
      expect(http.proxy_user).to eq('proxy+user')
      expect(http.proxy_pass).to eq('p@ss')
      expect(http.instance_variable_get(:@proxy_use_ssl)).to be(true)
    end

    it 'preserves normal proxy behavior without enforcement' do
      with_outbound_proxy(nil)
      http = Net::HTTP.new('example.com', 80, 'other-proxy', 3128)
      OutboundProxy.configure_net_http(http)

      expect(http.proxy_address).to eq('other-proxy')
      expect(http.proxy_port).to eq(3128)
    end
  end

  describe '.open_uri_options' do
    it 'leaves environment proxy settings in effect without enforcement' do
      with_outbound_proxy(nil)
      expect(OutboundProxy.open_uri_options).to eq({})
    end

    it 'sets an explicit proxy, bypassing environment no_proxy exclusions' do
      with_outbound_proxy('http://smokescreen:4750')
      expect(OutboundProxy.open_uri_options).to eq(proxy: 'http://smokescreen:4750')
    end

    it 'passes proxy credentials separately from the URL' do
      with_outbound_proxy('http://proxy%2Buser:p%40ss@smokescreen:4750')
      expect(OutboundProxy.open_uri_options).to eq(
        proxy_http_basic_authentication: ['http://smokescreen:4750', 'proxy+user', 'p@ss']
      )
    end
  end

  describe 'HTTP transport' do
    {
      'HTTParty' => ->(url) { HTTParty.get(url).body },
      'open-uri' => ->(url) { URI(url).open(**OutboundProxy.open_uri_options, &:read) },
      'Net::HTTP' => ->(url) {
        uri = URI(url)
        http = OutboundProxy.configure_net_http(Net::HTTP.new(uri.hostname, uri.port, nil))
        http.get(uri.request_uri).body
      }
    }.each do |client, request|
      it "routes #{client} through the enforced proxy for a no_proxy destination" do
        server = TCPServer.new('127.0.0.1', 0)
        with_outbound_proxy("http://127.0.0.1:#{server.addr[1]}")
        allow(ENV).to receive(:[]).with('no_proxy').and_return('*')
        OutboundProxy.configure!

        responder = Thread.new do
          socket = server.accept
          first_line = socket.gets
          while (line = socket.gets) && line != "\r\n"
          end
          socket.write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}")
          first_line
        ensure
          socket&.close
        end

        Timeout.timeout(5) do
          expect(request.call('http://127.0.0.1:9/probe')).to eq('{}')
          expect(responder.value).to eq("GET http://127.0.0.1:9/probe HTTP/1.1\r\n")
        end
      ensure
        responder&.kill
        responder&.join
        server&.close
      end
    end
  end
end
