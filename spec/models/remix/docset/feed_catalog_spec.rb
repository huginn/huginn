require 'rails_helper'

describe Remix::Docset::FeedCatalog do
  before do
    Rails.cache.clear
  end

  describe '.available_docsets' do
    let(:official_feed_list) do
      [
        { 'name' => 'NodeJS.xml', 'download_url' => 'https://raw.githubusercontent.com/Kapeli/feeds/master/NodeJS.xml' },
        { 'name' => 'Python_3.xml', 'download_url' => 'https://raw.githubusercontent.com/Kapeli/feeds/master/Python_3.xml' },
        { 'name' => 'Ruby_3.xml', 'download_url' => 'https://raw.githubusercontent.com/Kapeli/feeds/master/Ruby_3.xml' }
      ].to_json
    end

    let(:nodejs_feed_xml) do
      <<~XML
        <entry>
          <version>25.4.0</version>
          <url>http://sanfrancisco.kapeli.com/feeds/NodeJS.tgz</url>
          <url>http://london.kapeli.com/feeds/NodeJS.tgz</url>
        </entry>
      XML
    end

    let(:python_feed_xml) do
      <<~XML
        <entry>
          <version>3.12.0</version>
          <url>http://sanfrancisco.kapeli.com/feeds/Python_3.tgz</url>
        </entry>
      XML
    end

    let(:ruby_feed_xml) do
      <<~XML
        <entry>
          <version>3.3.0</version>
          <url>http://sanfrancisco.kapeli.com/feeds/Ruby_3.tgz</url>
        </entry>
      XML
    end

    let(:contrib_docsets_list) do
      [
        { 'name' => 'Tailwind_CSS', 'type' => 'dir', 'url' => 'https://api.github.com/repos/Kapeli/Dash-User-Contributions/contents/docsets/Tailwind_CSS' }
      ].to_json
    end

    let(:tailwind_docset_json) do
      {
        name: 'Tailwind CSS',
        version: '3.4.0',
        archive: 'Tailwind_CSS.tgz'
      }.to_json
    end

    before do
      # Stub official feeds listing
      stub_request(:get, Remix::Docset::FeedCatalog::OFFICIAL_FEEDS_API)
        .with(query: hash_including({}))
        .to_return(status: 200, body: official_feed_list, headers: { 'Content-Type' => 'application/json' })

      # Stub individual feed XML files
      stub_request(:get, 'https://raw.githubusercontent.com/Kapeli/feeds/master/NodeJS.xml')
        .to_return(status: 200, body: nodejs_feed_xml)
      stub_request(:get, 'https://raw.githubusercontent.com/Kapeli/feeds/master/Python_3.xml')
        .to_return(status: 200, body: python_feed_xml)
      stub_request(:get, 'https://raw.githubusercontent.com/Kapeli/feeds/master/Ruby_3.xml')
        .to_return(status: 200, body: ruby_feed_xml)

      # Stub contributed docsets listing
      stub_request(:get, Remix::Docset::FeedCatalog::CONTRIB_DOCSETS_API)
        .with(query: hash_including({}))
        .to_return(status: 200, body: contrib_docsets_list, headers: { 'Content-Type' => 'application/json' })

      # Stub contributed docset.json
      stub_request(:get, /raw\.githubusercontent\.com.*Tailwind_CSS.*docset\.json/)
        .to_return(status: 200, body: tailwind_docset_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a sorted list of available docsets from official feeds' do
      results = described_class.available_docsets
      names = results.map { |d| d[:name] }

      expect(names).to include('NodeJS', 'Python_3', 'Ruby_3')
    end

    it 'includes user-contributed docsets' do
      results = described_class.available_docsets
      tailwind = results.find { |d| d[:name] == 'Tailwind_CSS' }

      expect(tailwind).not_to be_nil
      expect(tailwind[:source]).to eq('user_contributed')
      expect(tailwind[:display_name]).to eq('Tailwind CSS')
    end

    it 'includes version information' do
      results = described_class.available_docsets
      nodejs = results.find { |d| d[:name] == 'NodeJS' }

      expect(nodejs[:version]).to eq('25.4.0')
    end

    it 'includes download URLs' do
      results = described_class.available_docsets
      nodejs = results.find { |d| d[:name] == 'NodeJS' }

      expect(nodejs[:urls]).to include('http://sanfrancisco.kapeli.com/feeds/NodeJS.tgz')
    end

    it 'filters results by query' do
      results = described_class.available_docsets(query: 'node')
      expect(results.length).to eq(1)
      expect(results.first[:name]).to eq('NodeJS')
    end

    it 'caches results' do
      # Use memory store for this test to verify caching behavior
      memory_store = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(memory_store)

      described_class.available_docsets
      described_class.available_docsets

      # Should only make one set of API calls (with pagination query params)
      expect(WebMock).to have_requested(:get, /#{Regexp.escape('api.github.com/repos/Kapeli/feeds/contents')}/).once
    end
  end

  describe '.find_docset' do
    before do
      allow(described_class).to receive(:available_docsets).and_return([
        { name: 'NodeJS', display_name: 'Node.js', source: 'official', version: '25.4.0',
          urls: ['http://sanfrancisco.kapeli.com/feeds/NodeJS.tgz'] }
      ])
    end

    it 'finds a docset by exact name' do
      result = described_class.find_docset('NodeJS')
      expect(result).not_to be_nil
      expect(result[:display_name]).to eq('Node.js')
    end

    it 'returns nil for unknown docset' do
      result = described_class.find_docset('NonExistent')
      expect(result).to be_nil
    end
  end
end
