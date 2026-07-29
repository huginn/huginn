require 'rails_helper'

describe Remix::Docset::Search do
  let!(:docset) do
    Docset.create!(
      name: 'TestDocset',
      display_name: 'Test Docset',
      identifier: 'com.test.docset',
      source: 'official',
      status: 'ready'
    )
  end

  let!(:page) do
    docset.docset_pages.create!(
      path: 'Array.html',
      title: 'Array',
      entry_type: 'Class',
      html_content: '<h1>Array</h1>',
      text_content: 'Array class documentation'
    )
  end

  let!(:chunk1) do
    docset.docset_chunks.create!(
      docset_page: page,
      entry_name: 'Array',
      entry_type: 'Class',
      content: 'Array is an ordered collection of elements. You can add, remove, and iterate over elements.',
      chunk_index: 0,
      token_count: 20
    )
  end

  let!(:chunk2) do
    docset.docset_chunks.create!(
      docset_page: page,
      entry_name: 'Array.push',
      entry_type: 'Method',
      content: 'push(element) adds one or more elements to the end of an array and returns the new length.',
      chunk_index: 0,
      token_count: 20
    )
  end

  let!(:other_docset) do
    Docset.create!(
      name: 'OtherDocset',
      display_name: 'Other Docset',
      identifier: 'com.other.docset',
      source: 'official',
      status: 'pending' # Not ready
    )
  end

  before do
    # Mock the embedding call for the search query
    allow(Remix::Docset::EmbeddingClient).to receive(:embed)
      .and_return(Array.new(Remix::Docset::EmbeddingClient.dimensions, 0.1))
  end

  describe '#results' do
    context 'when pgvector is not available (MySQL fallback)' do
      before do
        allow(DocsetChunk).to receive(:vector_search_available?).and_return(false)
      end

      it 'falls back to keyword search' do
        search = described_class.new('array collection')
        results = search.results

        expect(results).to be_an(Array)
        expect(results.length).to be >= 1
        expect(results.first[:entry_name]).to be_present
      end

      it 'only returns results from ready docsets' do
        search = described_class.new('array')
        results = search.results

        docset_names = results.map { |r| r[:docset] }.uniq
        expect(docset_names).not_to include('Other Docset')
      end

      it 'filters by docset_ids when provided' do
        search = described_class.new('array', docset_ids: [docset.id])
        results = search.results

        expect(results).to be_an(Array)
        results.each do |r|
          expect(r[:docset]).to eq('Test Docset')
        end
      end

      it 'filters by entry_types when provided' do
        search = described_class.new('array', entry_types: ['Method'])
        results = search.results

        results.each do |r|
          expect(r[:entry_type]).to eq('Method')
        end
      end

      it 'respects the limit parameter' do
        search = described_class.new('array', limit: 1)
        results = search.results

        expect(results.length).to be <= 1
      end

      it 'returns results with expected structure' do
        search = described_class.new('array')
        results = search.results

        if results.any?
          result = results.first
          expect(result).to have_key(:docset)
          expect(result).to have_key(:entry_name)
          expect(result).to have_key(:entry_type)
          expect(result).to have_key(:content)
          expect(result).to have_key(:path)
          expect(result).to have_key(:relevance)
        end
      end
    end

    context 'when pgvector is available' do
      before do
        allow(DocsetChunk).to receive(:vector_search_available?).and_return(true)

        # Mock the nearest_neighbors chain
        mock_scope = double('scope')
        allow(DocsetChunk).to receive(:joins).and_return(mock_scope)
        allow(mock_scope).to receive(:where).and_return(mock_scope)
        allow(mock_scope).to receive(:nearest_neighbors).and_return(mock_scope)
        allow(mock_scope).to receive(:limit).and_return([
          double(
            'chunk',
            entry_name: 'Array',
            entry_type: 'Class',
            content: 'Array is an ordered collection.',
            neighbor_distance: 0.15,
            docset: docset,
            docset_page: page
          )
        ])
      end

      it 'uses vector search' do
        search = described_class.new('ordered collection')
        results = search.results

        expect(results).to be_an(Array)
        expect(results.first[:entry_name]).to eq('Array')
        expect(results.first[:relevance]).to be_within(0.01).of(0.85)
      end
    end
  end
end
