require 'rails_helper'

describe 'OpenAPI Tools' do
  let(:user) { users(:bob) }

  let!(:ready_api) do
    Docset.create!(
      name: 'stripe.com',
      display_name: 'Stripe API',
      identifier: 'openapi:stripe.com',
      source: 'openapi',
      status: 'ready',
      version: '2022-11-15',
      entry_count: 120,
      chunk_count: 250,
      page_count: 150
    )
  end

  let!(:installing_api) do
    Docset.create!(
      name: 'openapi:github.com:api.github.com',
      display_name: 'GitHub v3 REST API',
      identifier: 'openapi:github.com:api.github.com',
      source: 'openapi',
      status: 'indexing',
      version: '1.1.4'
    )
  end

  # Also have a docset-type record to ensure filtering works
  let!(:docset_record) do
    Docset.create!(
      name: 'Ruby_3',
      display_name: 'Ruby 3',
      identifier: 'ruby3',
      source: 'official',
      status: 'ready',
      version: '3.3.0',
      entry_count: 5000,
      chunk_count: 8000,
      page_count: 2000
    )
  end

  describe Remix::Tools::ListApiSpecs do
    let(:tool) { described_class.new(user) }

    describe '.to_openai_tool' do
      it 'returns a valid OpenAI tool definition' do
        defn = described_class.to_openai_tool
        expect(defn[:type]).to eq('function')
        expect(defn[:function][:name]).to eq('list_api_specs')
        expect(defn[:function][:parameters]).to be_a(Hash)
      end
    end

    describe '#execute' do
      it 'lists installed OpenAPI specs only (not docsets)' do
        result = tool.execute({ 'filter' => 'installed' })

        expect(result[:success]).to be true
        names = result[:docsets].map { |d| d[:name] }
        expect(names).to include('stripe.com')
        expect(names).not_to include('Ruby_3')
      end

      it 'includes status and counts for installed specs' do
        result = tool.execute({ 'filter' => 'installed' })
        stripe = result[:docsets].find { |d| d[:name] == 'stripe.com' }

        expect(stripe[:status]).to eq('ready')
        expect(stripe[:entry_count]).to eq(120)
      end

      it 'lists available providers when filter is "available"' do
        allow(Remix::Openapi::Catalog).to receive(:available_providers).and_return(
          ['stripe.com', 'github.com', 'googleapis.com']
        )

        result = tool.execute({ 'filter' => 'available' })

        expect(result[:success]).to be true
        expect(result[:providers]).to include('stripe.com')
      end

      it 'auto-expands APIs when query narrows to few providers' do
        allow(Remix::Openapi::Catalog).to receive(:available_providers).with(query: 'stripe').and_return(
          ['stripe.com']
        )
        allow(Remix::Openapi::Catalog).to receive(:provider_apis).with('stripe.com').and_return([
          { name: 'stripe.com', provider: 'stripe.com', service_name: nil,
            title: 'Stripe API', description: 'The Stripe REST API.', version: '2022-11-15',
            openapi_url: 'https://example.com/stripe.json' }
        ])

        result = tool.execute({ 'filter' => 'available', 'query' => 'stripe' })

        expect(result[:success]).to be true
        expect(result[:providers_with_apis]).to be_a(Hash)
        expect(result[:providers_with_apis]['stripe.com']).to be_an(Array)
        expect(result[:providers_with_apis]['stripe.com'].first[:title]).to eq('Stripe API')
      end

      it 'lists provider APIs when provider is specified' do
        allow(Remix::Openapi::Catalog).to receive(:provider_apis).with('googleapis.com').and_return([
          { name: 'googleapis.com:drive', provider: 'googleapis.com', service_name: 'drive',
            title: 'Google Drive API', description: 'Drive API', version: 'v3',
            openapi_url: 'https://example.com/drive.json' }
        ])

        result = tool.execute({ 'filter' => 'available', 'provider' => 'googleapis.com' })

        expect(result[:success]).to be true
        expect(result[:apis]).to be_an(Array)
        expect(result[:apis].first[:title]).to eq('Google Drive API')
      end

      it 'defaults to listing installed specs' do
        result = tool.execute({})

        expect(result[:success]).to be true
        expect(result[:docsets].any? { |d| d[:name] == 'stripe.com' }).to be true
      end
    end
  end

  describe Remix::Tools::InstallApiSpec do
    let(:tool) { described_class.new(user) }

    describe '.to_openai_tool' do
      it 'returns a valid OpenAI tool definition' do
        defn = described_class.to_openai_tool
        expect(defn[:function][:name]).to eq('install_api_spec')
        expect(defn[:function][:parameters][:required]).to include('provider')
      end
    end

    describe '#execute' do
      before do
        allow(Remix::Openapi::Catalog).to receive(:find_api).with('twilio.com', service_name: nil).and_return({
          name: 'twilio.com',
          provider: 'twilio.com',
          service_name: nil,
          title: 'Twilio API',
          description: 'The Twilio REST API.',
          version: '1.0',
          openapi_url: 'https://api.apis.guru/v2/specs/twilio.com/1.0/openapi.json',
          categories: ['messaging']
        })

        # Prevent inline job execution in test
        allow(OpenapiInstallJob).to receive(:perform_later)
      end

      it 'creates a docset record and enqueues installation' do
        expect {
          result = tool.execute({ 'provider' => 'twilio.com' })
          expect(result[:success]).to be true
          expect(result[:message]).to include('started')
        }.to change(Docset, :count).by(1)

        docset = Docset.find_by(name: 'twilio.com')
        expect(docset.status).to eq('pending')
        expect(docset.source).to eq('openapi')
        expect(docset.display_name).to eq('Twilio API')
        expect(OpenapiInstallJob).to have_received(:perform_later).with(docset.id)
      end

      it 'installs a specific service from a multi-API provider' do
        allow(Remix::Openapi::Catalog).to receive(:find_api).with('googleapis.com', service_name: 'drive').and_return({
          name: 'googleapis.com:drive',
          provider: 'googleapis.com',
          service_name: 'drive',
          title: 'Google Drive API',
          description: 'Google Drive access',
          version: 'v3',
          openapi_url: 'https://api.apis.guru/v2/specs/googleapis.com/drive/v3/openapi.json',
          categories: []
        })

        expect {
          result = tool.execute({ 'provider' => 'googleapis.com', 'service' => 'drive' })
          expect(result[:success]).to be true
        }.to change(Docset, :count).by(1)

        docset = Docset.find_by(name: 'googleapis.com:drive')
        expect(docset.display_name).to eq('Google Drive API')
      end

      it 'returns error if already installed' do
        result = tool.execute({ 'provider' => 'stripe.com' })

        expect(result[:success]).to be false
        expect(result[:message]).to include('already installed')
      end

      it 'returns error if not found in catalog' do
        allow(Remix::Openapi::Catalog).to receive(:find_api).with('nonexistent.com', service_name: nil).and_return(nil)

        result = tool.execute({ 'provider' => 'nonexistent.com' })

        expect(result[:success]).to be false
        expect(result[:message]).to include('not found')
      end

      it 'returns error if provider is blank' do
        result = tool.execute({ 'provider' => '' })

        expect(result[:success]).to be false
        expect(result[:message]).to include('required')
      end
    end
  end

  describe Remix::Tools::UninstallApiSpec do
    let(:tool) { described_class.new(user) }

    describe '.to_openai_tool' do
      it 'returns a valid OpenAI tool definition' do
        defn = described_class.to_openai_tool
        expect(defn[:function][:name]).to eq('uninstall_api_spec')
      end
    end

    describe '#requires_confirmation?' do
      it 'requires confirmation' do
        expect(tool.requires_confirmation?).to be true
      end
    end

    describe '#execute' do
      it 'removes the API spec and all associated data' do
        expect {
          result = tool.execute({ 'name' => 'stripe.com' })
          expect(result[:success]).to be true
        }.to change(Docset, :count).by(-1)

        expect(Docset.find_by(name: 'stripe.com')).to be_nil
      end

      it 'returns error for non-existent spec' do
        result = tool.execute({ 'name' => 'nonexistent.com' })

        expect(result[:success]).to be false
        expect(result[:message]).to include('not found')
      end

      it 'returns error for blank name' do
        result = tool.execute({ 'name' => '' })

        expect(result[:success]).to be false
        expect(result[:message]).to include('required')
      end
    end
  end
end
