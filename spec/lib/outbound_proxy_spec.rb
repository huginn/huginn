require 'rails_helper'

describe OutboundProxy do
  def with_outbound_proxy(value)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('OUTBOUND_PROXY').and_return(value)
  end

  after do
    with_outbound_proxy(nil)
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
  end
end
