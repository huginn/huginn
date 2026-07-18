module Remix
  module Docset
    class EmbeddingClient
      DEFAULT_MODEL = 'text-embedding-3-small'.freeze
      DEFAULT_DIMENSIONS = 1536
      MAX_INPUT_TOKENS = 8000 # Conservative limit for Venice/OpenAI compat APIs

      class ApiError < StandardError; end

      def self.model
        ENV.fetch('EMBEDDING_MODEL', DEFAULT_MODEL)
      end

      def self.dimensions
        ENV.fetch('EMBEDDING_DIMENSIONS', DEFAULT_DIMENSIONS.to_s).to_i
      end

      # Single text → single vector
      def self.embed(text)
        embed_batch([text]).first
      end

      # Batch texts → batch vectors (sorted by input order)
      def self.embed_batch(texts)
        sanitized = texts.map { |t| truncate_input(t) }
        body = { model: model, input: sanitized }
        response = api_request(body)

        if response['error']
          error_msg = response.dig('error', 'message') || response['error'].to_s
          raise ApiError, error_msg
        end

        response['data']
          .sort_by { |d| d['index'] }
          .map { |d| d['embedding'] }
      end

      private

      # Truncate input to stay within token limits (rough estimate: 4 chars/token)
      def self.truncate_input(text)
        max_chars = MAX_INPUT_TOKENS * 4
        text.to_s.length > max_chars ? text[0, max_chars] : text.to_s
      end

      def self.api_request(body)
        url = "#{base_url}/embeddings"
        conn = Faraday.new do |f|
          f.options.timeout = 120
          f.options.open_timeout = 30
          f.adapter Faraday.default_adapter
        end

        response = conn.post(url, body.to_json, {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}"
        })

        parsed = JSON.parse(response.body)

        # Check for HTTP-level errors
        unless response.success?
          error_msg = parsed.dig('error', 'message') || parsed.dig('error', 'type') || "HTTP #{response.status}: #{response.body.to_s[0, 500]}"
          raise ApiError, error_msg
        end

        parsed
      end

      def self.base_url
        ENV.fetch('OPENAI_BASE_URL', 'https://api.openai.com/v1').chomp('/')
      end

      def self.api_key
        ENV['OPENAI_API_KEY']
      end
    end
  end
end
