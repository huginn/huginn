module Remix
  module Tools
    # ---- list_docsets ----
    class ListDocsets < BaseTool
      def self.tool_name = 'list_docsets'
      def self.description = 'List available or installed documentation docsets. Use filter "installed" to see what\'s ready, or "available" to browse the catalog.'
      def self.parameters
        {
          type: 'object',
          properties: {
            filter: {
              type: 'string',
              enum: %w[installed available],
              description: 'Whether to list installed docsets or browse available ones (default: installed)'
            },
            query: {
              type: 'string',
              description: 'Optional search query to filter results by name'
            }
          },
          required: []
        }
      end

      def execute(params)
        filter = params['filter'] || 'installed'
        query = params['query']

        case filter
        when 'installed'
          list_installed(query)
        when 'available'
          list_available(query)
        else
          error_response("Invalid filter: #{filter}. Use 'installed' or 'available'.")
        end
      end

      private

      def list_installed(query)
        scope = ::Docset.all
        scope = scope.by_name(query) if query.present?

        docsets = scope.order(:display_name).map do |d|
          {
            name: d.name,
            display_name: d.display_name,
            version: d.version,
            source: d.source,
            status: d.status,
            entry_count: d.entry_count,
            chunk_count: d.chunk_count,
            page_count: d.page_count
          }
        end

        success_response("Found #{docsets.length} installed docset(s)", docsets: docsets)
      end

      def list_available(query)
        catalog = if query.present?
                    Remix::Docset::FeedCatalog.available_docsets(query: query)
                  else
                    Remix::Docset::FeedCatalog.available_docsets
                  end

        # Mark which ones are already installed
        installed_names = ::Docset.pluck(:name).to_set

        docsets = catalog.first(50).map do |d|
          {
            name: d[:name],
            display_name: d[:display_name],
            version: d[:version],
            source: d[:source],
            installed: installed_names.include?(d[:name])
          }
        end

        success_response(
          "Found #{catalog.length} available docset(s)#{catalog.length > 50 ? ' (showing first 50)' : ''}",
          docsets: docsets,
          total: catalog.length
        )
      end
    end

    # ---- install_docset ----
    class InstallDocset < BaseTool
      def self.tool_name = 'install_docset'
      def self.description = 'Download and index a documentation docset for semantic search. Installation happens in the background and may take a few minutes for large docsets.'
      def self.parameters
        {
          type: 'object',
          properties: {
            name: {
              type: 'string',
              description: 'Name of the docset to install (from the catalog, e.g. "NodeJS", "Python_3", "Ruby_3")'
            }
          },
          required: %w[name]
        }
      end

      def execute(params)
        name = params['name'].to_s.strip
        return error_response('Docset name is required') if name.blank?

        # Check if already installed
        existing = ::Docset.find_by(name: name)
        if existing
          if existing.ready?
            return error_response("'#{name}' is already installed and ready (#{existing.entry_count} entries)")
          elsif existing.installing?
            return error_response("'#{name}' is currently being installed (status: #{existing.status})")
          elsif existing.error?
            # Allow re-installation of failed docsets
            existing.destroy
          end
        end

        # Find in catalog
        catalog_entry = Remix::Docset::FeedCatalog.find_docset(name)
        return error_response("Docset '#{name}' not found in catalog. Use list_docsets with filter 'available' to see available docsets.") unless catalog_entry

        # Create record and enqueue
        docset = ::Docset.create!(
          name: catalog_entry[:name],
          display_name: catalog_entry[:display_name],
          identifier: catalog_entry[:name].downcase.gsub(/[^a-z0-9]/, '_'),
          source: catalog_entry[:source],
          version: catalog_entry[:version],
          feed_url: catalog_entry[:feed_url],
          status: 'pending'
        )

        DocsetInstallJob.perform_later(docset.id)

        success_response(
          "Installation of '#{catalog_entry[:display_name]}' started. This runs in the background and may take a few minutes. Use list_docsets to check status.",
          docset_id: docset.id,
          name: docset.name,
          display_name: docset.display_name,
          status: 'pending'
        )
      end
    end

    # ---- search_docs ----
    class SearchDocs < BaseTool
      def self.tool_name = 'search_docs'
      def self.description = 'Search across installed documentation docsets using semantic search. Returns relevant documentation snippets for classes, methods, functions, etc.'
      def self.parameters
        {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Natural language search query or API name to look up (e.g. "how to create a TCP server", "Array.prototype.map", "http.createServer")'
            },
            docsets: {
              type: 'array',
              items: { type: 'string' },
              description: 'Optional: limit search to specific docsets by name (e.g. ["NodeJS", "Python_3"])'
            },
            entry_types: {
              type: 'array',
              items: { type: 'string' },
              description: 'Optional: filter by entry type (e.g. ["Class", "Method", "Function", "Property"])'
            },
            limit: {
              type: 'integer',
              description: 'Maximum number of results (default: 10, max: 20)'
            }
          },
          required: %w[query]
        }
      end

      def execute(params)
        query = params['query'].to_s.strip
        return error_response('Search query is required') if query.blank?

        # Resolve docset names to IDs
        docset_ids = nil
        if params['docsets'].present?
          docsets = ::Docset.ready.where(name: params['docsets'])
          docset_ids = docsets.pluck(:id)
          if docset_ids.empty?
            return error_response("None of the specified docsets are installed: #{params['docsets'].join(', ')}")
          end
        end

        limit = [(params['limit'] || 10).to_i, 20].min
        limit = 10 if limit <= 0

        search = Remix::Docset::Search.new(
          query,
          docset_ids: docset_ids,
          entry_types: params['entry_types'],
          limit: limit
        )

        results = search.results

        success_response(
          "Found #{results.length} result(s) for '#{query}'",
          results: results,
          query: query
        )
      end
    end

    # ---- uninstall_docset ----
    class UninstallDocset < BaseTool
      def self.tool_name = 'uninstall_docset'
      def self.description = 'Remove an installed documentation docset and all its indexed data.'
      def self.parameters
        {
          type: 'object',
          properties: {
            name: {
              type: 'string',
              description: 'Name of the docset to uninstall'
            }
          },
          required: %w[name]
        }
      end

      def requires_confirmation?
        true
      end

      def confirmation_message(params)
        "Are you sure you want to uninstall the '#{params['name']}' docset? This will remove all indexed documentation."
      end

      def execute(params)
        name = params['name'].to_s.strip
        return error_response('Docset name is required') if name.blank?

        docset = ::Docset.find_by(name: name)
        return error_response("Docset '#{name}' not found") unless docset

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
