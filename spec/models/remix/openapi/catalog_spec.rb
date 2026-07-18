require 'rails_helper'

describe Remix::Openapi::Catalog do
  before do
    Rails.cache.clear
  end

  let(:providers_response) do
    {
      data: [
        'stripe.com',
        'github.com',
        'googleapis.com',
        'twilio.com',
        'slack.com'
      ]
    }.to_json
  end

  let(:stripe_provider_response) do
    {
      apis: {
        'stripe.com' => {
          added: '2017-11-14T11:01:43.000Z',
          info: {
            description: 'The Stripe REST API. Please see https://stripe.com/docs/api for more details.',
            title: 'Stripe API',
            version: '2022-11-15',
            'x-apisguru-categories' => ['financial'],
            'x-providerName' => 'stripe.com'
          },
          updated: '2023-03-06T07:12:59.965Z',
          swaggerUrl: 'https://api.apis.guru/v2/specs/stripe.com/2022-11-15/openapi.json',
          swaggerYamlUrl: 'https://api.apis.guru/v2/specs/stripe.com/2022-11-15/openapi.yaml',
          openapiVer: '3.0.0',
          link: 'https://api.apis.guru/v2/specs/stripe.com/2022-11-15.json'
        }
      }
    }.to_json
  end

  let(:googleapis_provider_response) do
    {
      apis: {
        'googleapis.com:drive' => {
          added: '2020-01-07T11:38:39.000Z',
          info: {
            description: 'The Google Drive API allows clients to access resources from Google Drive.',
            title: 'Google Drive API',
            version: 'v3',
            'x-apisguru-categories' => ['analytics', 'media'],
            'x-providerName' => 'googleapis.com',
            'x-serviceName' => 'drive'
          },
          updated: '2023-04-21T23:09:23.065Z',
          swaggerUrl: 'https://api.apis.guru/v2/specs/googleapis.com/drive/v3/openapi.json',
          swaggerYamlUrl: 'https://api.apis.guru/v2/specs/googleapis.com/drive/v3/openapi.yaml',
          openapiVer: '3.0.0',
          link: 'https://api.apis.guru/v2/specs/googleapis.com:drive/v3.json'
        },
        'googleapis.com:calendar' => {
          added: '2020-01-07T11:38:39.000Z',
          info: {
            description: 'Manipulates events and other calendar data.',
            title: 'Calendar API',
            version: 'v3',
            'x-apisguru-categories' => ['analytics'],
            'x-providerName' => 'googleapis.com',
            'x-serviceName' => 'calendar'
          },
          updated: '2023-04-21T23:09:23.065Z',
          swaggerUrl: 'https://api.apis.guru/v2/specs/googleapis.com/calendar/v3/openapi.json',
          swaggerYamlUrl: 'https://api.apis.guru/v2/specs/googleapis.com/calendar/v3/openapi.yaml',
          openapiVer: '3.0.0',
          link: 'https://api.apis.guru/v2/specs/googleapis.com:calendar/v3.json'
        }
      }
    }.to_json
  end

  describe '.available_providers' do
    before do
      stub_request(:get, 'https://api.apis.guru/v2/providers.json')
        .to_return(status: 200, body: providers_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a list of provider names' do
      results = described_class.available_providers

      expect(results).to be_an(Array)
      expect(results).to include('stripe.com', 'github.com', 'googleapis.com')
    end

    it 'filters providers by query' do
      results = described_class.available_providers(query: 'stripe')

      expect(results.length).to eq(1)
      expect(results.first).to eq('stripe.com')
    end

    it 'is case-insensitive when filtering' do
      results = described_class.available_providers(query: 'GOOGLE')

      expect(results.length).to eq(1)
      expect(results.first).to eq('googleapis.com')
    end

    it 'caches the provider list' do
      memory_store = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(memory_store)

      described_class.available_providers
      described_class.available_providers

      expect(WebMock).to have_requested(:get, 'https://api.apis.guru/v2/providers.json').once
    end
  end

  describe '.provider_apis' do
    before do
      stub_request(:get, 'https://api.apis.guru/v2/stripe.com.json')
        .to_return(status: 200, body: stripe_provider_response, headers: { 'Content-Type' => 'application/json' })

      stub_request(:get, 'https://api.apis.guru/v2/googleapis.com.json')
        .to_return(status: 200, body: googleapis_provider_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns APIs for a single-API provider' do
      apis = described_class.provider_apis('stripe.com')

      expect(apis).to be_an(Array)
      expect(apis.length).to eq(1)

      api = apis.first
      expect(api[:name]).to eq('stripe.com')
      expect(api[:title]).to eq('Stripe API')
      expect(api[:description]).to include('Stripe REST API')
      expect(api[:version]).to eq('2022-11-15')
      expect(api[:openapi_url]).to include('openapi.json')
      expect(api[:provider]).to eq('stripe.com')
    end

    it 'returns APIs for a multi-API provider' do
      apis = described_class.provider_apis('googleapis.com')

      expect(apis.length).to eq(2)
      names = apis.map { |a| a[:service_name] }
      expect(names).to include('drive', 'calendar')
    end

    it 'includes title and description for each API' do
      apis = described_class.provider_apis('googleapis.com')
      drive = apis.find { |a| a[:service_name] == 'drive' }

      expect(drive[:title]).to eq('Google Drive API')
      expect(drive[:description]).to include('Google Drive')
    end

    it 'caches provider API data' do
      memory_store = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(memory_store)

      described_class.provider_apis('stripe.com')
      described_class.provider_apis('stripe.com')

      expect(WebMock).to have_requested(:get, 'https://api.apis.guru/v2/stripe.com.json').once
    end

    it 'returns empty array for non-existent provider' do
      stub_request(:get, 'https://api.apis.guru/v2/nonexistent.com.json')
        .to_return(status: 404, body: 'Not Found')

      apis = described_class.provider_apis('nonexistent.com')
      expect(apis).to eq([])
    end
  end

  describe '.find_api' do
    before do
      stub_request(:get, 'https://api.apis.guru/v2/stripe.com.json')
        .to_return(status: 200, body: stripe_provider_response, headers: { 'Content-Type' => 'application/json' })

      stub_request(:get, 'https://api.apis.guru/v2/googleapis.com.json')
        .to_return(status: 200, body: googleapis_provider_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'finds a single-API provider by name' do
      api = described_class.find_api('stripe.com')

      expect(api).not_to be_nil
      expect(api[:title]).to eq('Stripe API')
      expect(api[:openapi_url]).to be_present
    end

    it 'finds a specific service from a multi-API provider' do
      api = described_class.find_api('googleapis.com', service_name: 'drive')

      expect(api).not_to be_nil
      expect(api[:title]).to eq('Google Drive API')
      expect(api[:service_name]).to eq('drive')
    end

    it 'returns nil for unknown provider' do
      stub_request(:get, 'https://api.apis.guru/v2/unknown.com.json')
        .to_return(status: 404, body: 'Not Found')

      api = described_class.find_api('unknown.com')
      expect(api).to be_nil
    end

    it 'returns the first API when no service specified for multi-API provider' do
      api = described_class.find_api('googleapis.com')
      expect(api).not_to be_nil
    end
  end

  describe '.clear_cache!' do
    it 'clears all cached data' do
      memory_store = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(memory_store)

      stub_request(:get, 'https://api.apis.guru/v2/providers.json')
        .to_return(status: 200, body: providers_response, headers: { 'Content-Type' => 'application/json' })

      described_class.available_providers
      described_class.clear_cache!

      described_class.available_providers
      expect(WebMock).to have_requested(:get, 'https://api.apis.guru/v2/providers.json').twice
    end
  end
end
