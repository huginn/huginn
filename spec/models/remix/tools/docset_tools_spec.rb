require 'rails_helper'

describe 'Docset Tools' do
  let(:user) { users(:bob) }

  let!(:ready_docset) do
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

  let!(:installing_docset) do
    Docset.create!(
      name: 'Python_3',
      display_name: 'Python 3',
      identifier: 'python3',
      source: 'official',
      status: 'indexing',
      version: '3.12.0'
    )
  end

  describe Remix::Tools::ListDocsets do
    let(:tool) { described_class.new(user) }

    describe '.to_openai_tool' do
      it 'returns a valid OpenAI tool definition' do
        defn = described_class.to_openai_tool
        expect(defn[:type]).to eq('function')
        expect(defn[:function][:name]).to eq('list_docsets')
        expect(defn[:function][:parameters]).to be_a(Hash)
      end
    end

    describe '#execute' do
      it 'lists installed docsets when filter is "installed"' do
        result = tool.execute({ 'filter' => 'installed' })

        expect(result[:success]).to be true
        docsets = result[:docsets]
        expect(docsets).to be_an(Array)
        names = docsets.map { |d| d[:name] }
        expect(names).to include('Ruby_3')
      end

      it 'includes status and counts for installed docsets' do
        result = tool.execute({ 'filter' => 'installed' })
        ruby = result[:docsets].find { |d| d[:name] == 'Ruby_3' }

        expect(ruby[:status]).to eq('ready')
        expect(ruby[:entry_count]).to eq(5000)
      end

      it 'lists available docsets from catalog when filter is "available"' do
        allow(Remix::Docset::FeedCatalog).to receive(:available_docsets).and_return([
          { name: 'NodeJS', display_name: 'Node.js', source: 'official', version: '25.4.0', urls: ['http://example.com/NodeJS.tgz'] }
        ])

        result = tool.execute({ 'filter' => 'available' })

        expect(result[:success]).to be true
        expect(result[:docsets].first[:name]).to eq('NodeJS')
      end

      it 'filters available docsets by query' do
        allow(Remix::Docset::FeedCatalog).to receive(:available_docsets).with(query: 'node').and_return([
          { name: 'NodeJS', display_name: 'Node.js', source: 'official', version: '25.4.0', urls: [] }
        ])

        result = tool.execute({ 'filter' => 'available', 'query' => 'node' })

        expect(result[:success]).to be true
        expect(result[:docsets].length).to eq(1)
      end

      it 'defaults to listing installed docsets' do
        result = tool.execute({})

        expect(result[:success]).to be true
        expect(result[:docsets].any? { |d| d[:name] == 'Ruby_3' }).to be true
      end
    end
  end

  describe Remix::Tools::InstallDocset do
    let(:tool) { described_class.new(user) }

    describe '.to_openai_tool' do
      it 'returns a valid OpenAI tool definition' do
        defn = described_class.to_openai_tool
        expect(defn[:function][:name]).to eq('install_docset')
        expect(defn[:function][:parameters][:required]).to include('name')
      end
    end

    describe '#execute' do
      before do
        allow(Remix::Docset::FeedCatalog).to receive(:find_docset).with('NodeJS').and_return({
          name: 'NodeJS', display_name: 'Node.js', source: 'official',
          version: '25.4.0', urls: ['http://example.com/NodeJS.tgz'],
          feed_url: 'https://raw.githubusercontent.com/Kapeli/feeds/master/NodeJS.xml'
        })
      end

      it 'creates a docset record and enqueues installation' do
        # Prevent inline job execution in test
        allow(DocsetInstallJob).to receive(:perform_later)

        expect {
          result = tool.execute({ 'name' => 'NodeJS' })
          expect(result[:success]).to be true
          expect(result[:message]).to include('started')
        }.to change(Docset, :count).by(1)

        docset = Docset.find_by(name: 'NodeJS')
        expect(docset.status).to eq('pending')
        expect(docset.display_name).to eq('Node.js')
        expect(DocsetInstallJob).to have_received(:perform_later).with(docset.id)
      end

      it 'returns error if docset is already installed' do
        result = tool.execute({ 'name' => 'Ruby_3' })

        expect(result[:success]).to be false
        expect(result[:message]).to include('already installed')
      end

      it 'returns error if docset is not found in catalog' do
        allow(Remix::Docset::FeedCatalog).to receive(:find_docset).with('NonExistent').and_return(nil)

        result = tool.execute({ 'name' => 'NonExistent' })

        expect(result[:success]).to be false
        expect(result[:message]).to include('not found')
      end
    end
  end

  describe Remix::Tools::SearchDocs do
    let(:tool) { described_class.new(user) }

    let!(:page) do
      ready_docset.docset_pages.create!(
        path: 'Array.html',
        title: 'Array',
        entry_type: 'Class'
      )
    end

    let!(:chunk) do
      ready_docset.docset_chunks.create!(
        docset_page: page,
        entry_name: 'Array',
        entry_type: 'Class',
        content: 'Array is an ordered collection of elements.',
        chunk_index: 0,
        token_count: 10
      )
    end

    describe '.to_openai_tool' do
      it 'returns a valid OpenAI tool definition' do
        defn = described_class.to_openai_tool
        expect(defn[:function][:name]).to eq('search_docs')
        expect(defn[:function][:parameters][:required]).to include('query')
      end
    end

    describe '#execute' do
      before do
        allow(DocsetChunk).to receive(:vector_search_available?).and_return(false)
      end

      it 'searches across installed docsets' do
        result = tool.execute({ 'query' => 'array collection' })

        expect(result[:success]).to be true
        expect(result[:results]).to be_an(Array)
      end

      it 'returns error for blank query' do
        result = tool.execute({ 'query' => '' })

        expect(result[:success]).to be false
        expect(result[:message]).to include('required')
      end

      it 'filters by docset names' do
        result = tool.execute({ 'query' => 'array', 'docsets' => ['Ruby_3'] })

        expect(result[:success]).to be true
      end

      it 'filters by entry types' do
        result = tool.execute({ 'query' => 'array', 'entry_types' => ['Class'] })

        expect(result[:success]).to be true
      end

      it 'returns no results message when nothing found' do
        result = tool.execute({ 'query' => 'xyznonexistent' })

        expect(result[:success]).to be true
        expect(result[:results]).to eq([])
      end
    end
  end

  describe Remix::Tools::UninstallDocset do
    let(:tool) { described_class.new(user) }

    describe '.to_openai_tool' do
      it 'returns a valid OpenAI tool definition' do
        defn = described_class.to_openai_tool
        expect(defn[:function][:name]).to eq('uninstall_docset')
      end
    end

    describe '#requires_confirmation?' do
      it 'requires confirmation' do
        expect(tool.requires_confirmation?).to be true
      end
    end

    describe '#execute' do
      it 'removes the docset and all associated data' do
        expect {
          result = tool.execute({ 'name' => 'Ruby_3' })
          expect(result[:success]).to be true
        }.to change(Docset, :count).by(-1)

        expect(Docset.find_by(name: 'Ruby_3')).to be_nil
      end

      it 'returns error for non-existent docset' do
        result = tool.execute({ 'name' => 'NonExistent' })

        expect(result[:success]).to be false
        expect(result[:message]).to include('not found')
      end
    end
  end
end
