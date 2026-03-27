module Remix
  module Openapi
    class Installer
      MAX_CHUNK_TOKENS = 1000
      EMBED_BATCH_SIZE = 10
      HTTP_METHODS = %w[get post put patch delete options head trace].freeze

      def initialize(docset_record)
        @docset = docset_record
      end

      def install!
        @docset.update!(status: 'downloading')
        spec = download_spec

        @docset.update!(status: 'extracting')
        info = spec['info'] || {}
        @docset.update!(version: info['version']) if info['version'].present?

        @docset.update!(status: 'indexing')
        all_chunks = []
        endpoint_count = 0

        # Process paths/endpoints
        paths = spec['paths'] || {}
        paths.each do |path, path_item|
          next unless path_item.is_a?(Hash)

          HTTP_METHODS.each do |method|
            operation = path_item[method]
            next unless operation.is_a?(Hash)

            endpoint_count += 1
            chunks = process_endpoint(method.upcase, path, operation)
            all_chunks.concat(chunks)
          end
        end

        # Process component schemas
        schemas = spec.dig('components', 'schemas') || {}
        schemas.each do |schema_name, schema_def|
          next unless schema_def.is_a?(Hash)

          chunks = process_schema(schema_name, schema_def)
          all_chunks.concat(chunks)
        end

        # Batch embed and persist all chunks
        persist_chunks_with_embeddings(all_chunks)

        @docset.update!(
          status: 'ready',
          entry_count: endpoint_count,
          page_count: @docset.docset_pages.count,
          chunk_count: @docset.docset_chunks.count
        )
      rescue => e
        @docset.update!(status: 'error', error_message: e.message)
        raise
      end

      private

      def download_spec
        url = @docset.feed_url
        raise "No spec URL configured for #{@docset.name}" if url.blank?

        conn = Faraday.new do |f|
          f.options.timeout = 120
          f.options.open_timeout = 30
          f.adapter Faraday.default_adapter
        end

        response = conn.get(url, nil, {
          'User-Agent' => 'Huginn Remix/1.0',
          'Accept' => 'application/json'
        })

        raise "Failed to download spec: HTTP #{response.status}" unless response.success?

        JSON.parse(response.body)
      rescue JSON::ParserError => e
        raise "Failed to parse OpenAPI spec JSON: #{e.message}"
      end

      def process_endpoint(method, path, operation)
        text = render_endpoint_text(method, path, operation)
        title = operation['summary'] || operation['operationId'] || "#{method} #{path}"
        tag = Array(operation['tags']).first || method

        page = @docset.docset_pages.create!(
          path: "#{method} #{path}",
          title: title,
          entry_type: tag,
          text_content: text
        )

        sub_chunks = chunk_text(text, MAX_CHUNK_TOKENS)
        sub_chunks.each_with_index.map do |chunk_content, idx|
          {
            page: page,
            entry_name: title,
            entry_type: tag,
            content: chunk_content,
            chunk_index: idx,
            token_count: estimate_tokens(chunk_content)
          }
        end
      end

      def process_schema(schema_name, schema_def)
        text = render_schema_text(schema_name, schema_def)
        page_path = "schema:#{schema_name}"

        page = @docset.docset_pages.create!(
          path: page_path,
          title: "Schema: #{schema_name}",
          entry_type: 'Schema',
          text_content: text
        )

        sub_chunks = chunk_text(text, MAX_CHUNK_TOKENS)
        sub_chunks.each_with_index.map do |chunk_content, idx|
          {
            page: page,
            entry_name: schema_name,
            entry_type: 'Schema',
            content: chunk_content,
            chunk_index: idx,
            token_count: estimate_tokens(chunk_content)
          }
        end
      end

      def render_endpoint_text(method, path, operation)
        lines = []
        lines << "#{method} #{path}"
        lines << operation['summary'] if operation['summary'].present?
        lines << ""
        lines << operation['description'] if operation['description'].present?

        # Parameters
        params = operation['parameters']
        if params.is_a?(Array) && params.any?
          lines << ""
          lines << "Parameters:"
          params.each do |param|
            req = param['required'] ? 'required' : 'optional'
            type = param.dig('schema', 'type') || 'any'
            desc = param['description'] || ''
            lines << "- #{param['name']} (#{param['in']}, #{req}): #{type} - #{desc}"
          end
        end

        # Request body
        request_body = operation['requestBody']
        if request_body.is_a?(Hash)
          lines << ""
          req_label = request_body['required'] ? '(required)' : '(optional)'
          lines << "Request Body #{req_label}:"

          content = request_body['content'] || {}
          content.each do |media_type, media_def|
            schema = media_def['schema'] || {}
            lines << "  Content-Type: #{media_type}"
            render_schema_properties(schema, lines, indent: 2)
          end
        end

        # Responses
        responses = operation['responses']
        if responses.is_a?(Hash) && responses.any?
          lines << ""
          lines << "Responses:"
          responses.each do |status_code, response_def|
            desc = response_def.is_a?(Hash) ? response_def['description'] : response_def.to_s
            lines << "  #{status_code}: #{desc}"
          end
        end

        lines.join("\n")
      end

      def render_schema_text(schema_name, schema_def)
        lines = []
        lines << "Schema: #{schema_name}"
        lines << "Type: #{schema_def['type']}" if schema_def['type'].present?
        lines << ""
        lines << schema_def['description'] if schema_def['description'].present?

        render_schema_properties(schema_def, lines, indent: 0)

        lines.join("\n")
      end

      def render_schema_properties(schema_def, lines, indent: 0)
        return unless schema_def.is_a?(Hash)

        properties = schema_def['properties']
        return unless properties.is_a?(Hash)

        required_props = Array(schema_def['required'])
        prefix = '  ' * indent

        lines << "" if indent == 0
        lines << "#{prefix}Properties:"
        properties.each do |prop_name, prop_def|
          next unless prop_def.is_a?(Hash)

          type = prop_def['type'] || 'any'
          desc = prop_def['description'] || ''
          req = required_props.include?(prop_name) ? ', required' : ''
          nullable = prop_def['nullable'] ? ', nullable' : ''
          enum_vals = prop_def['enum'] ? " [#{prop_def['enum'].join(', ')}]" : ''

          lines << "#{prefix}- #{prop_name}: #{type}#{enum_vals}#{req}#{nullable} - #{desc}"
        end
      end

      def persist_chunks_with_embeddings(chunks)
        has_embedding_column = DocsetChunk.column_names.include?('embedding')

        chunks.each_slice(EMBED_BATCH_SIZE) do |batch|
          embeddings = if has_embedding_column
                         Remix::Docset::EmbeddingClient.embed_batch(batch.map { |c| c[:content] })
                       else
                         batch.map { nil }
                       end

          batch.each_with_index do |chunk, i|
            attrs = {
              docset_page: chunk[:page],
              entry_name: chunk[:entry_name],
              entry_type: chunk[:entry_type],
              content: chunk[:content],
              chunk_index: chunk[:chunk_index],
              token_count: chunk[:token_count]
            }
            attrs[:embedding] = embeddings[i] if has_embedding_column && embeddings[i]

            @docset.docset_chunks.create!(attrs)
          end
        end
      end

      def chunk_text(text, max_tokens)
        return [] if text.blank?

        estimated = estimate_tokens(text)
        return [text] if estimated <= max_tokens

        # Split on paragraph boundaries
        paragraphs = text.split(/\n{2,}/)
        chunks = []
        current_chunk = ''

        paragraphs.each do |para|
          para = para.strip
          next if para.blank?

          if estimate_tokens(current_chunk + "\n\n" + para) <= max_tokens
            current_chunk = current_chunk.blank? ? para : "#{current_chunk}\n\n#{para}"
          else
            chunks << current_chunk unless current_chunk.blank?
            if estimate_tokens(para) > max_tokens
              chunks.concat(split_on_sentences(para, max_tokens))
              current_chunk = ''
            else
              current_chunk = para
            end
          end
        end

        chunks << current_chunk unless current_chunk.blank?
        chunks
      end

      def split_on_sentences(text, max_tokens)
        sentences = text.split(/(?<=[.!?])\s+/)
        chunks = []
        current = ''

        sentences.each do |sentence|
          if estimate_tokens(current + ' ' + sentence) <= max_tokens
            current = current.blank? ? sentence : "#{current} #{sentence}"
          else
            chunks << current unless current.blank?
            current = sentence
          end
        end

        chunks << current unless current.blank?
        chunks
      end

      def estimate_tokens(text)
        (text.to_s.length / 4.0).ceil
      end
    end
  end
end
