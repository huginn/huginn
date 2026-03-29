require 'tempfile'
require 'fileutils'

module Remix
  module Docset
    class Installer
      MAX_CHUNK_TOKENS = 1000
      EMBED_BATCH_SIZE = 10 # texts per embedding API call

      def initialize(docset_record)
        @docset = docset_record
        @temp_paths = []
      end

      def install!
        @docset.update!(status: 'downloading')
        archive_path = download_archive

        @docset.update!(status: 'extracting')
        bundle_dir = extract_archive(archive_path)

        plist = parse_plist(bundle_dir)
        entries = read_search_index(bundle_dir)

        @docset.update!(
          status: 'indexing',
          identifier: plist[:identifier] || @docset.identifier,
          platform_family: plist[:platform_family]
        )

        store_pages_and_chunks(bundle_dir, entries)

        @docset.update!(
          status: 'ready',
          entry_count: entries.size,
          page_count: @docset.docset_pages.count,
          chunk_count: @docset.docset_chunks.count
        )
      rescue => e
        @docset.update!(status: 'error', error_message: e.message)
        raise
      ensure
        cleanup_temp_files
      end

      private

      def download_archive
        urls = feed_urls
        raise "No download URLs available for #{@docset.name}" if urls.empty?

        last_error = nil
        urls.each do |url|
          begin
            return download_from_url(url)
          rescue => e
            last_error = e
            Rails.logger.warn("Failed to download from #{url}: #{e.message}")
          end
        end

        raise "All download mirrors failed for #{@docset.name}: #{last_error&.message}"
      end

      def feed_urls
        # Try to get URLs from the feed catalog entry
        catalog_entry = FeedCatalog.find_docset(@docset.name)
        return catalog_entry[:urls] if catalog_entry&.dig(:urls)&.any?

        # Fallback: construct URL from name
        ["http://sanfrancisco.kapeli.com/feeds/#{@docset.name}.tgz"]
      end

      def download_from_url(url)
        tmpfile = Tempfile.new(['docset', '.tgz'])
        @temp_paths << tmpfile.path

        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.open_timeout = 30
        http.read_timeout = 300 # Large docsets can take a while

        request = Net::HTTP::Get.new(uri.request_uri)
        request['User-Agent'] = 'Huginn Remix/1.0'

        http.request(request) do |response|
          case response
          when Net::HTTPSuccess
            File.open(tmpfile.path, 'wb') do |file|
              response.read_body { |chunk| file.write(chunk) }
            end
          when Net::HTTPRedirection
            tmpfile.close
            return download_from_url(response['location'])
          else
            raise "HTTP #{response.code}: #{response.message}"
          end
        end

        tmpfile.close
        tmpfile.path
      end

      def extract_archive(archive_path)
        tmpdir = Dir.mktmpdir('docset_extract')
        @temp_paths << tmpdir

        result = system('tar', '-xzf', archive_path, '-C', tmpdir)
        raise "Failed to extract archive" unless result

        # Find the .docset bundle inside the extracted directory
        docset_bundles = Dir.glob(File.join(tmpdir, '*.docset'))
        if docset_bundles.empty?
          # Try one level deeper
          docset_bundles = Dir.glob(File.join(tmpdir, '**', '*.docset'))
        end

        raise "No .docset bundle found in archive" if docset_bundles.empty?

        docset_bundles.first
      end

      def parse_plist(bundle_dir)
        plist_path = File.join(bundle_dir, 'Contents', 'Info.plist')
        raise "Info.plist not found at #{plist_path}" unless File.exist?(plist_path)

        xml = File.read(plist_path)
        doc = Nokogiri::XML(xml)

        # Parse Apple plist XML format: key-value pairs inside <dict>
        dict = doc.at_css('dict')
        raise "Invalid plist: no <dict> found" unless dict

        plist = {}
        keys = dict.css('> key')
        keys.each do |key|
          value_node = key.next_element
          next unless value_node

          val = case value_node.name
                when 'string' then value_node.text
                when 'true' then true
                when 'false' then false
                when 'integer' then value_node.text.to_i
                else value_node.text
                end

          plist[key.text] = val
        end

        {
          identifier: plist['CFBundleIdentifier'],
          name: plist['CFBundleName'],
          platform_family: plist['DocSetPlatformFamily'],
          is_dash_docset: plist['isDashDocset']
        }
      end

      def read_search_index(bundle_dir)
        db_path = File.join(bundle_dir, 'Contents', 'Resources', 'docSet.dsidx')
        raise "Search index not found at #{db_path}" unless File.exist?(db_path)

        require 'sqlite3'
        db = SQLite3::Database.new(db_path)
        db.results_as_hash = true

        rows = db.execute('SELECT name, type, path FROM searchIndex ORDER BY name')
        db.close

        rows.map do |row|
          {
            name: row['name'],
            type: row['type'],
            path: row['path']
          }
        end
      end

      def store_pages_and_chunks(bundle_dir, entries)
        documents_dir = File.join(bundle_dir, 'Contents', 'Resources', 'Documents')

        # Group entries by their base path (before any #anchor)
        entries_by_path = entries.group_by { |e| e[:path].to_s.split('#').first }

        all_chunks_to_embed = []

        entries_by_path.each do |path, page_entries|
          next if path.blank?

          html_path = File.join(documents_dir, path)
          next unless File.exist?(html_path)

          html = File.read(html_path, encoding: 'UTF-8') rescue File.read(html_path, encoding: 'ISO-8859-1').encode('UTF-8')
          text = extract_text(html)

          page = @docset.docset_pages.create!(
            path: path,
            title: page_entries.first[:name],
            entry_type: page_entries.first[:type],
            html_content: html,
            text_content: text
          )

          # Create chunks for each entry pointing to this page
          page_entries.each do |entry|
            section_text = extract_section(html, entry)
            sub_chunks = chunk_text(section_text, MAX_CHUNK_TOKENS)

            sub_chunks.each_with_index do |chunk_content, idx|
              all_chunks_to_embed << {
                page: page,
                entry_name: entry[:name],
                entry_type: entry[:type],
                content: chunk_content,
                chunk_index: idx,
                token_count: estimate_tokens(chunk_content)
              }
            end
          end
        end

        # Batch embed and persist chunks
        persist_chunks_with_embeddings(all_chunks_to_embed)
      end

      def persist_chunks_with_embeddings(chunks)
        has_embedding_column = DocsetChunk.column_names.include?('embedding')

        chunks.each_slice(EMBED_BATCH_SIZE) do |batch|
          embeddings = if has_embedding_column
                         EmbeddingClient.embed_batch(batch.map { |c| c[:content] })
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

      def extract_text(html)
        doc = Nokogiri::HTML(html)
        doc.css('script, style, noscript, iframe, nav').remove

        main = doc.at_css('main, article, [role="main"], .content, #content')
        target = main || doc.at_css('body') || doc

        target.text
          .gsub(/[ \t]+/, ' ')
          .gsub(/\n{3,}/, "\n\n")
          .strip
      end

      def extract_section(html, entry)
        path = entry[:path].to_s
        anchor = path.include?('#') ? path.split('#', 2).last : nil

        doc = Nokogiri::HTML(html)
        doc.css('script, style, noscript').remove

        if anchor.present?
          # Try to find the anchor element by id or name attribute
          escaped_anchor = anchor.gsub("'", "\\\\'")
          target = doc.at_css("[id='#{escaped_anchor}']") ||
                   doc.at_css("[name='#{escaped_anchor}']") ||
                   doc.at_css("[name*='#{escaped_anchor}']")

          if target
            # Collect text from this element through to the next sibling heading
            text_parts = [target.text]
            sibling = target.next_element
            while sibling && !heading?(sibling)
              text_parts << sibling.text
              sibling = sibling.next_element
            end
            return text_parts.join("\n").gsub(/\s+/, ' ').strip
          end
        end

        # Fallback: return full page text
        extract_text(html)
      end

      def heading?(node)
        %w[h1 h2 h3 h4 h5 h6].include?(node.name.downcase)
      end

      def chunk_text(text, max_tokens)
        return [] if text.blank?

        estimated = estimate_tokens(text)
        return [text] if estimated <= max_tokens

        # Split on paragraph boundaries first
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
            # If a single paragraph exceeds max_tokens, split on sentences
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
        # Rough estimate: ~4 characters per token for English text
        (text.to_s.length / 4.0).ceil
      end

      def cleanup_temp_files
        @temp_paths.each do |path|
          if File.directory?(path)
            FileUtils.rm_rf(path)
          elsif File.exist?(path)
            FileUtils.rm_f(path)
          end
        rescue => e
          Rails.logger.warn("Failed to clean up temp path #{path}: #{e.message}")
        end
      end
    end
  end
end
