module Remix
  module Openapi
    class Catalog
      BASE_URL = 'https://api.apis.guru/v2'.freeze
      PROVIDERS_CACHE_KEY = 'openapi_providers_catalog'.freeze
      PROVIDER_CACHE_PREFIX = 'openapi_provider_'.freeze
      CACHE_TTL = 24.hours

      # Returns array of provider name strings, optionally filtered by query
      def self.available_providers(query: nil)
        providers = Rails.cache.fetch(PROVIDERS_CACHE_KEY, expires_in: CACHE_TTL) { fetch_providers }
        if query.present?
          providers.select { |p| p.downcase.include?(query.downcase) }
        else
          providers
        end
      end

      # Returns array of API hashes for a given provider
      # Each hash: { name:, provider:, service_name:, title:, description:, version:, openapi_url:, categories: }
      def self.provider_apis(provider_name)
        cache_key = "#{PROVIDER_CACHE_PREFIX}#{provider_name}"
        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_provider_apis(provider_name) }
      end

      # Find a specific API. For single-API providers, service_name is optional.
      # For multi-API providers (e.g. googleapis.com), pass service_name to pick one.
      def self.find_api(provider_name, service_name: nil)
        apis = provider_apis(provider_name)
        return nil if apis.empty?

        if service_name.present?
          apis.find { |a| a[:service_name] == service_name }
        else
          apis.first
        end
      end

      def self.clear_cache!
        Rails.cache.delete(PROVIDERS_CACHE_KEY)
        # Note: individual provider caches will expire naturally
      end

      private

      def self.fetch_providers
        body = http_get("#{BASE_URL}/providers.json")
        return [] if body.blank?

        data = JSON.parse(body)
        data['data'] || []
      rescue JSON::ParserError => e
        Rails.logger.error("Openapi::Catalog: Failed to parse providers.json: #{e.message}")
        []
      rescue => e
        Rails.logger.error("Openapi::Catalog: Failed to fetch providers: #{e.message}")
        []
      end

      def self.fetch_provider_apis(provider_name)
        body = http_get("#{BASE_URL}/#{provider_name}.json")
        return [] if body.blank?

        data = JSON.parse(body)
        apis_hash = data['apis']
        return [] unless apis_hash.is_a?(Hash)

        apis_hash.map do |api_key, api_data|
          parse_api_entry(api_key, api_data, provider_name)
        end.compact.sort_by { |a| a[:title].to_s.downcase }
      rescue JSON::ParserError => e
        Rails.logger.error("Openapi::Catalog: Failed to parse #{provider_name}.json: #{e.message}")
        []
      rescue => e
        Rails.logger.error("Openapi::Catalog: Failed to fetch provider #{provider_name}: #{e.message}")
        []
      end

      def self.parse_api_entry(api_key, api_data, provider_name)
        info = api_data['info'] || {}
        service_name = info['x-serviceName']

        {
          name: api_key,
          provider: provider_name,
          service_name: service_name,
          title: info['title'] || api_key,
          description: info['description'] || '',
          version: info['version'],
          openapi_url: api_data['swaggerUrl'],
          openapi_yaml_url: api_data['swaggerYamlUrl'],
          openapi_version: api_data['openapiVer'],
          categories: info['x-apisguru-categories'] || [],
          updated: api_data['updated']
        }
      end

      def self.http_get(url)
        conn = Faraday.new do |f|
          f.options.timeout = 30
          f.options.open_timeout = 10
          f.adapter Faraday.default_adapter
        end

        response = conn.get(url, nil, { 'User-Agent' => 'Huginn Remix/1.0', 'Accept' => 'application/json' })
        response.success? ? response.body : nil
      rescue => e
        Rails.logger.warn("Openapi::Catalog HTTP GET failed for #{url}: #{e.message}")
        nil
      end
    end
  end
end
