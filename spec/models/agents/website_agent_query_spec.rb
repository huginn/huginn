require 'rails_helper'

describe Agents::WebsiteAgent do
  describe "query parameters" do
    let(:agent) do
      described_class.create!(
        name: "Query parameters",
        user: users(:bob),
        options: {
          'expected_update_period_in_days' => '2',
          'url' => 'https://query.example.test/feed',
          'type' => 'json',
          'mode' => 'all',
          'extract' => { 'value' => { 'path' => '$.value' } },
          'template' => { 'request_url' => '{{ _response_.url }}' }
        }
      )
    end

    before do
      stub_request(:get, /query\.example\.test/)
        .to_return(status: 200, body: '{"value": "ok"}', headers: { 'Content-Type' => 'application/json' })
    end

    it "retains repeated query parameters and their order" do
      url = 'https://query.example.test/feed?z=first&a=1&z=second&a=2'
      agent.options['url'] = url
      agent.check

      expect(agent.events.last.payload['request_url']).to eq(url)
    end

    it "preserves bracketed names, escaped values and valueless parameters" do
      url = 'https://query.example.test/feed?tag[]=a&tag[]=b&value=a%2Fb&value=a+b&empty=&flag'
      agent.options['url'] = url
      agent.check

      expect(agent.events.last.payload['request_url']).to eq(url)
    end

    it "preserves query parameters on a redirect" do
      url = 'https://query.example.test/final?a=1&a=2&b=%2B'
      stub_request(:get, 'https://query.example.test/feed')
        .to_return(status: 302, headers: { 'Location' => url })
      agent.check

      expect(agent.events.last.payload['request_url']).to eq(url)
    end

    it "preserves repeated parameters in event-derived URLs" do
      url = 'https://query.example.test/feed?a=1&a=2'
      agent.options['url_from_event'] = '{{ url }}'
      event = Event.new(payload: { 'url' => url })
      agent.receive([event])

      expect(agent.events.last.payload['request_url']).to eq(url)
    end

    it "retains the explicit disable_url_encoding option" do
      url = 'https://query.example.test/feed?z=1&z=2&a=%2f'
      agent.options['url'] = url
      agent.options['disable_url_encoding'] = true
      agent.check

      expect(agent.events.last.payload['request_url']).to eq(url)
      expect(agent.faraday.options.params_encoder).to eq(WebRequestConcern::DoNotEncoder)
    end

    it "honors proxy bypass rules for the requested URL" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('http_proxy').and_return('http://proxy.example.test:3128')
      allow(ENV).to receive(:[]).with('HTTP_PROXY').and_return(nil)
      allow(ENV).to receive(:[]).with('no_proxy').and_return('query.example.test')
      agent.options['url'] = 'http://query.example.test/feed?a=1&a=2'
      request_proxies = []
      allow(agent.faraday).to receive(:build_request).and_wrap_original do |original, *args, &block|
        request = original.call(*args, &block)
        request_proxies << request.options.proxy
        request
      end
      agent.check

      expect(request_proxies).to eq([nil])
      expect(agent.events.last.payload['request_url']).to eq(agent.options['url'])
    end

    it "keeps the connection encoder unchanged after checking a URL" do
      agent.check

      expect(agent.faraday.options.params_encoder).to be_nil
    end
  end
end
