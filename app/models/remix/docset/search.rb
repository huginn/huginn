module Remix
  module Docset
    class Search
      DEFAULT_LIMIT = 10

      def initialize(query, docset_ids: nil, entry_types: nil, limit: DEFAULT_LIMIT)
        @query = query
        @docset_ids = docset_ids
        @entry_types = entry_types
        @limit = limit
      end

      def results
        if DocsetChunk.vector_search_available?
          vector_search
        else
          keyword_search
        end
      end

      private

      # ---- Vector search (pgvector) ----

      def vector_search
        query_embedding = EmbeddingClient.embed(@query)

        scope = DocsetChunk
                  .joins(:docset)
                  .where(docsets: { status: 'ready' })

        scope = scope.where(docset_id: @docset_ids) if @docset_ids.present?
        scope = scope.where(entry_type: @entry_types) if @entry_types.present?

        results = scope.nearest_neighbors(:embedding, query_embedding, distance: :cosine)
                       .limit(@limit)

        results.map do |chunk|
          {
            docset: chunk.docset.display_name,
            entry_name: chunk.entry_name,
            entry_type: chunk.entry_type,
            content: chunk.content,
            path: chunk.docset_page.path,
            distance: chunk.neighbor_distance,
            relevance: (1 - chunk.neighbor_distance).round(4)
          }
        end
      end

      # ---- Keyword search (fallback for MySQL) ----

      def keyword_search
        words = @query.to_s.downcase.split(/\s+/).reject(&:blank?)
        return [] if words.empty?

        scope = DocsetChunk
                  .joins(:docset, :docset_page)
                  .where(docsets: { status: 'ready' })

        scope = scope.where(docset_id: @docset_ids) if @docset_ids.present?
        scope = scope.where(entry_type: @entry_types) if @entry_types.present?

        # Load candidates and score them in Ruby
        # Limit the candidate pool to avoid loading the entire table
        candidates = scope.select(
          'docset_chunks.*, docsets.display_name AS docset_display_name, docset_pages.path AS page_path'
        ).limit(@limit * 10)

        scored = candidates.map do |chunk|
          score = calculate_keyword_score(chunk, words)
          next if score <= 0

          {
            docset: chunk.docset_display_name,
            entry_name: chunk.entry_name,
            entry_type: chunk.entry_type,
            content: chunk.content,
            path: chunk.page_path,
            distance: 1.0 - score,
            relevance: score.round(4)
          }
        end.compact

        scored.sort_by { |r| -r[:relevance] }.first(@limit)
      end

      def calculate_keyword_score(chunk, words)
        content_lower = chunk.content.to_s.downcase
        name_lower = chunk.entry_name.to_s.downcase

        matched = words.count do |word|
          content_lower.include?(word) || name_lower.include?(word)
        end

        return 0 if matched == 0

        base_score = matched.to_f / words.length

        # Boost if entry name matches
        name_boost = words.any? { |w| name_lower.include?(w) } ? 0.2 : 0.0

        [base_score + name_boost, 1.0].min
      end
    end
  end
end
