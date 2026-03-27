require 'rails_helper'

describe Remix::Docset::EmbeddingClient do
  let(:dims) { described_class.dimensions }

  describe '.model' do
    it 'defaults to text-embedding-3-small' do
      expect(described_class.model).to eq('text-embedding-3-small')
    end

    it 'reads from EMBEDDING_MODEL env var' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('EMBEDDING_MODEL', anything).and_return('custom-model')
      expect(described_class.model).to eq('custom-model')
    end
  end

  describe '.dimensions' do
    it 'defaults to 1536' do
      expect(described_class.dimensions).to eq(1536)
    end

    it 'reads from EMBEDDING_DIMENSIONS env var' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('EMBEDDING_DIMENSIONS', anything).and_return('1024')
      expect(described_class.dimensions).to eq(1024)
    end
  end

  describe '.embed' do
    it 'returns a single embedding vector' do
      stub_request(:post, "https://api.openai.com/v1/embeddings")
        .with(
          body: hash_including('model' => 'text-embedding-3-small', 'input' => ['hello world']),
          headers: { 'Content-Type' => 'application/json' }
        )
        .to_return(
          status: 200,
          body: {
            data: [{ index: 0, embedding: Array.new(dims, 0.1) }]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = described_class.embed('hello world')
      expect(result).to be_an(Array)
      expect(result.length).to eq(dims)
      expect(result.first).to eq(0.1)
    end
  end

  describe '.embed_batch' do
    it 'returns multiple embedding vectors in input order' do
      texts = ['hello', 'world', 'foo']

      stub_request(:post, "https://api.openai.com/v1/embeddings")
        .with(
          body: hash_including('model' => 'text-embedding-3-small', 'input' => texts)
        )
        .to_return(
          status: 200,
          body: {
            data: [
              { index: 2, embedding: Array.new(dims, 0.3) },
              { index: 0, embedding: Array.new(dims, 0.1) },
              { index: 1, embedding: Array.new(dims, 0.2) }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      results = described_class.embed_batch(texts)
      expect(results.length).to eq(3)
      # Should be sorted by index
      expect(results[0].first).to eq(0.1)
      expect(results[1].first).to eq(0.2)
      expect(results[2].first).to eq(0.3)
    end

    it 'uses custom base URL from environment' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('OPENAI_BASE_URL').and_return('https://custom.api.com/v1/')
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('OPENAI_BASE_URL', anything).and_return('https://custom.api.com/v1/')

      stub_request(:post, "https://custom.api.com/v1/embeddings")
        .to_return(
          status: 200,
          body: {
            data: [{ index: 0, embedding: Array.new(dims, 0.1) }]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      described_class.embed_batch(['test'])
    end

    it 'raises on API errors' do
      stub_request(:post, "https://api.openai.com/v1/embeddings")
        .to_return(
          status: 401,
          body: { error: { message: 'Invalid API key' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect {
        described_class.embed_batch(['test'])
      }.to raise_error(Remix::Docset::EmbeddingClient::ApiError, /Invalid API key/)
    end

    it 'truncates excessively long input texts' do
      long_text = 'x' * 40_000 # Exceeds MAX_INPUT_TOKENS * 4

      stub_request(:post, "https://api.openai.com/v1/embeddings")
        .with { |req|
          body = JSON.parse(req.body)
          body['input'].first.length <= 32_000 # MAX_INPUT_TOKENS * 4
        }
        .to_return(
          status: 200,
          body: {
            data: [{ index: 0, embedding: Array.new(dims, 0.1) }]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = described_class.embed_batch([long_text])
      expect(result.first.length).to eq(dims)
    end
  end
end
