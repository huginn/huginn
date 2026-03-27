module Remix
  module Docset
    class FeedCatalog
      OFFICIAL_FEEDS_API = 'https://api.github.com/repos/Kapeli/feeds/contents'.freeze
      CONTRIB_DOCSETS_API = 'https://api.github.com/repos/Kapeli/Dash-User-Contributions/contents/docsets'.freeze
      CACHE_KEY = 'docset_feed_catalog'.freeze
      CACHE_TTL = 24.hours

      # Returns array of hashes: { name:, display_name:, source:, version:, urls:, feed_url: }
      def self.available_docsets(query: nil)
        catalog = Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_catalog }
        if query.present?
          catalog.select { |d| d[:display_name].downcase.include?(query.downcase) || d[:name].downcase.include?(query.downcase) }
        else
          catalog
        end
      end

      def self.find_docset(name)
        available_docsets.find { |d| d[:name] == name }
      end

      def self.clear_cache!
        Rails.cache.delete(CACHE_KEY)
      end

      private

      def self.fetch_catalog
        official = fetch_official_feeds
        contributed = fetch_contributed_docsets
        (official + contributed).sort_by { |d| d[:display_name].downcase }
      rescue => e
        Rails.logger.error("Failed to fetch docset catalog: #{e.message}")
        []
      end

      def self.fetch_official_feeds
        response = github_api_get(OFFICIAL_FEEDS_API)
        return [] unless response.is_a?(Array)

        xml_files = response.select { |f| f['name'].to_s.end_with?('.xml') }

        xml_files.filter_map do |file|
          parse_official_feed(file)
        rescue => e
          Rails.logger.warn("Failed to parse feed #{file['name']}: #{e.message}")
          nil
        end
      end

      def self.parse_official_feed(file)
        feed_name = file['name'].sub(/\.xml$/, '')
        feed_url = file['download_url']

        xml_body = http_get(feed_url)
        return nil if xml_body.blank?

        doc = Nokogiri::XML(xml_body)
        version = doc.at_css('version')&.text
        urls = doc.css('url').map(&:text)

        return nil if urls.empty?

        display_name = feed_name.gsub('_', ' ').gsub(/(\d)/, ' \1').strip.squeeze(' ')

        {
          name: feed_name,
          display_name: display_name,
          source: 'official',
          version: version,
          urls: urls,
          feed_url: feed_url
        }
      end

      def self.fetch_contributed_docsets
        response = github_api_get(CONTRIB_DOCSETS_API)
        return [] unless response.is_a?(Array)

        dirs = response.select { |f| f['type'] == 'dir' }

        dirs.filter_map do |dir|
          parse_contributed_docset(dir)
        rescue => e
          Rails.logger.warn("Failed to parse contributed docset #{dir['name']}: #{e.message}")
          nil
        end
      end

      def self.parse_contributed_docset(dir)
        docset_name = dir['name']
        json_url = "https://raw.githubusercontent.com/Kapeli/Dash-User-Contributions/master/docsets/#{docset_name}/docset.json"

        json_body = http_get(json_url)
        return nil if json_body.blank?

        meta = JSON.parse(json_body)
        archive = meta['archive'] || "#{docset_name}.tgz"
        base_url = "https://raw.githubusercontent.com/Kapeli/Dash-User-Contributions/master/docsets/#{docset_name}"

        {
          name: docset_name,
          display_name: meta['name'] || docset_name.gsub('_', ' '),
          source: 'user_contributed',
          version: meta['version'],
          urls: ["#{base_url}/#{archive}"],
          feed_url: json_url
        }
      end

      def self.github_api_get(url)
        headers = { 'Accept' => 'application/vnd.github.v3+json', 'User-Agent' => 'Huginn Remix/1.0' }
        token = ENV['GITHUB_TOKEN']
        headers['Authorization'] = "token #{token}" if token.present?

        conn = Faraday.new do |f|
          f.options.timeout = 30
          f.adapter Faraday.default_adapter
        end

        # Handle pagination
        all_items = []
        page = 1

        loop do
          response = conn.get(url, { per_page: 100, page: page }, headers)
          break unless response.success?

          items = JSON.parse(response.body)
          break unless items.is_a?(Array) && items.any?

          all_items.concat(items)
          page += 1

          # Stop if no Link header or no next page
          break unless response.headers['link']&.include?('rel="next"')
        end

        all_items
      end

      def self.http_get(url)
        conn = Faraday.new do |f|
          f.options.timeout = 15
          f.adapter Faraday.default_adapter
        end

        response = conn.get(url, nil, { 'User-Agent' => 'Huginn Remix/1.0' })
        response.success? ? response.body : nil
      rescue => e
        Rails.logger.warn("HTTP GET failed for #{url}: #{e.message}")
        nil
      end
    end
  end
end
