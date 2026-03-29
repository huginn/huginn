module Remix
  module Tools
    # ---- list_api_specs ----
    class ListApiSpecs < BaseTool
      def self.tool_name = 'list_api_specs'
      def self.description = 'List available or installed OpenAPI specs from the APIs.guru catalog. Use filter "installed" to see imported specs, or "available" to browse providers. Specify a provider to see its individual APIs.'
      def self.parameters
        {
          type: 'object',
          properties: {
            filter: {
              type: 'string',
              enum: %w[installed available],
              description: 'Whether to list installed API specs or browse available providers (default: installed)'
            },
            query: {
              type: 'string',
              description: 'Optional search query to filter results by name'
            },
            provider: {
              type: 'string',
              description: 'When filter is "available", specify a provider name (e.g. "googleapis.com") to list its individual APIs'
            }
          },
          required: []
        }
      end

      def execute(params)
        filter = params['filter'] || 'installed'
        query = params['query']
        provider = params['provider']

        case filter
        when 'installed'
          list_installed(query)
        when 'available'
          if provider.present?
            list_provider_apis(provider)
          else
            list_providers(query)
          end
        else
          error_response("Invalid filter: #{filter}. Use 'installed' or 'available'.")
        end
      end

      private

      def list_installed(query)
        scope = ::Docset.where(source: 'openapi')
        scope = scope.by_name(query) if query.present?

        docsets = scope.order(:display_name).map do |d|
          {
            name: d.name,
            display_name: d.display_name,
            version: d.version,
            status: d.status,
            entry_count: d.entry_count,
            chunk_count: d.chunk_count,
            page_count: d.page_count
          }
        end

        success_response("Found #{docsets.length} installed API spec(s)", docsets: docsets)
      end

      def list_providers(query)
        providers = if query.present?
                      Remix::Openapi::Catalog.available_providers(query: query)
                    else
                      Remix::Openapi::Catalog.available_providers
                    end

        # Mark which ones are already installed
        installed_names = ::Docset.where(source: 'openapi').pluck(:name).to_set

        # When query narrows to a small number of providers, auto-expand their APIs
        if query.present? && providers.length.between?(1, 5)
          return list_providers_with_apis(providers, installed_names)
        end

        success_response(
          "Found #{providers.length} available provider(s)#{providers.length > 100 ? ' (showing first 100)' : ''}. Use list_api_specs with a provider name to see its individual APIs, or install_api_spec to install one.",
          providers: providers.first(100),
          total: providers.length
        )
      end

      def list_providers_with_apis(providers, installed_names)
        result = {}
        providers.each do |provider|
          apis = Remix::Openapi::Catalog.provider_apis(provider)
          result[provider] = apis.first(20).map do |a|
            {
              name: a[:name],
              service_name: a[:service_name],
              title: a[:title],
              description: a[:description].to_s.truncate(200),
              version: a[:version],
              installed: installed_names.include?(a[:name])
            }
          end
        end

        total_apis = result.values.sum(&:length)
        success_response(
          "Found #{providers.length} provider(s) matching query with #{total_apis} API(s). Use install_api_spec to install one.",
          providers_with_apis: result,
          total_providers: providers.length,
          total_apis: total_apis
        )
      end

      def list_provider_apis(provider)
        apis = Remix::Openapi::Catalog.provider_apis(provider)

        installed_names = ::Docset.where(source: 'openapi').pluck(:name).to_set

        api_list = apis.first(50).map do |a|
          {
            name: a[:name],
            service_name: a[:service_name],
            title: a[:title],
            description: a[:description].to_s.truncate(200),
            version: a[:version],
            installed: installed_names.include?(a[:name])
          }
        end

        success_response(
          "Found #{apis.length} API(s) for provider '#{provider}'#{apis.length > 50 ? ' (showing first 50)' : ''}",
          apis: api_list,
          provider: provider,
          total: apis.length
        )
      end
    end

    # ---- install_api_spec ----
    class InstallApiSpec < BaseTool
      def self.tool_name = 'install_api_spec'
      def self.description = 'Download and index an OpenAPI spec from the APIs.guru catalog for semantic search. For multi-API providers like googleapis.com, specify the service name (e.g. "drive").'
      def self.parameters
        {
          type: 'object',
          properties: {
            provider: {
              type: 'string',
              description: 'Provider name (e.g. "stripe.com", "googleapis.com", "twilio.com")'
            },
            service: {
              type: 'string',
              description: 'Optional: service name for multi-API providers (e.g. "drive" for googleapis.com)'
            }
          },
          required: %w[provider]
        }
      end

      def execute(params)
        provider = params['provider'].to_s.strip
        service = params['service'].to_s.strip.presence
        return error_response('Provider name is required') if provider.blank?

        # Check if already installed by likely name patterns
        candidate_names = [provider]
        candidate_names << "#{provider}:#{service}" if service.present?
        existing = ::Docset.where(source: 'openapi').where(name: candidate_names).first

        if existing
          if existing.ready?
            return error_response("'#{existing.display_name}' is already installed and ready (#{existing.entry_count} endpoints)")
          elsif existing.installing?
            return error_response("'#{existing.display_name}' is currently being installed (status: #{existing.status})")
          elsif existing.error?
            existing.destroy
          end
        end

        # Look up in catalog
        api_entry = Remix::Openapi::Catalog.find_api(provider, service_name: service)
        return error_response("API spec for '#{provider}'#{service ? ":#{service}" : ''} not found in the APIs.guru catalog. Use list_api_specs with filter 'available' to browse providers.") unless api_entry

        api_name = api_entry[:name]

        # Double-check by canonical name (catalog name may differ from simple provider name)
        existing = ::Docset.find_by(name: api_name, source: 'openapi') unless candidate_names.include?(api_name)
        if existing
          if existing.ready?
            return error_response("'#{existing.display_name}' is already installed and ready (#{existing.entry_count} endpoints)")
          elsif existing.installing?
            return error_response("'#{existing.display_name}' is currently being installed (status: #{existing.status})")
          elsif existing.error?
            existing.destroy
          end
        end

        # Create record and enqueue
        docset = ::Docset.create!(
          name: api_name,
          display_name: api_entry[:title] || api_name,
          identifier: "openapi:#{api_name}",
          source: 'openapi',
          version: api_entry[:version],
          feed_url: api_entry[:openapi_url],
          status: 'pending'
        )

        OpenapiInstallJob.perform_later(docset.id)

        success_response(
          "Installation of '#{docset.display_name}' started. This runs in the background and may take a few minutes. Use list_api_specs to check status.",
          docset_id: docset.id,
          name: docset.name,
          display_name: docset.display_name,
          status: 'pending'
        )
      end
    end

    # ---- uninstall_api_spec ----
    class UninstallApiSpec < BaseTool
      def self.tool_name = 'uninstall_api_spec'
      def self.description = 'Remove an installed OpenAPI spec and all its indexed data.'
      def self.parameters
        {
          type: 'object',
          properties: {
            name: {
              type: 'string',
              description: 'Name of the API spec to uninstall (e.g. "stripe.com" or "googleapis.com:drive")'
            }
          },
          required: %w[name]
        }
      end

      def requires_confirmation?
        true
      end

      def confirmation_message(params)
        "Are you sure you want to uninstall the '#{params['name']}' API spec? This will remove all indexed documentation."
      end

      def execute(params)
        name = params['name'].to_s.strip
        return error_response('API spec name is required') if name.blank?

        docset = ::Docset.find_by(name: name, source: 'openapi')
        return error_response("API spec '#{name}' not found") unless docset

        page_count = docset.page_count
        chunk_count = docset.chunk_count
        docset.destroy!

        success_response(
          "Uninstalled '#{docset.display_name}' (removed #{page_count} pages and #{chunk_count} chunks)"
        )
      end
    end
  end
end
