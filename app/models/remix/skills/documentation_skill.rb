module Remix
  module Skills
    class DocumentationSkill < BaseSkill
      def self.name = 'documentation'
      def self.description = 'Guidance for searching and using documentation docsets'

      def self.triggers
        ['documentation', 'docs', 'docset', 'look up', 'how does',
         'api reference', 'what is the syntax', 'show me the docs',
         'man page', 'reference', 'class reference', 'method reference',
         'openapi', 'api spec', 'rest api', 'swagger', 'endpoint',
         'api documentation']
      end

      def self.context(user)
        installed_docsets = ::Docset.ready.where.not(source: 'openapi').pluck(:display_name, :entry_count)
        installed_apis = ::Docset.ready.where(source: 'openapi').pluck(:display_name, :entry_count)

        <<~CONTEXT
          ## Documentation Search

          You have access to Dash-compatible documentation docsets and OpenAPI specs from the APIs.guru catalog.
          Use the `search_docs` tool to find relevant documentation across all installed sources.

          ### Installed Docsets
          #{format_list(installed_docsets, 'docset')}

          ### Installed API Specs (OpenAPI)
          #{format_list(installed_apis, 'API spec')}

          ### Docset Tools
          - `list_docsets` — Browse available or installed Dash docsets
          - `install_docset` — Download and index a Dash docset (runs in background)
          - `search_docs` — Semantic search across ALL installed documentation (docsets + API specs)
          - `uninstall_docset` — Remove an installed docset

          ### OpenAPI Tools
          - `list_api_specs` — Browse available providers or installed API specs from APIs.guru
          - `install_api_spec` — Download and index an OpenAPI spec (runs in background)
          - `uninstall_api_spec` — Remove an installed API spec

          ### Tips
          - Search queries work best as natural language questions or API names
          - `search_docs` searches across BOTH docsets and API specs
          - For multi-API providers (e.g. googleapis.com), use `list_api_specs` with provider param to see individual APIs
          - Installation is asynchronous — large specs may take a few minutes
        CONTEXT
      end

      private

      def self.format_list(items, type_label)
        if items.any?
          items.map { |name, count| "- **#{name}** (#{count} entries)" }.join("\n")
        else
          "No #{type_label}s installed yet."
        end
      end
    end
  end
end
