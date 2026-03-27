class DocsetChunk < ActiveRecord::Base
  belongs_to :docset
  belongs_to :docset_page

  validates :content, presence: true

  # pgvector integration is configured at runtime via has_neighbors
  # Call DocsetChunk.configure_vector_search! after database is confirmed to support pgvector
  def self.configure_vector_search!
    return if @vector_search_configured
    return unless defined?(Neighbor)

    has_neighbors :embedding
    @vector_search_configured = true
  rescue => e
    Rails.logger.warn("Could not configure vector search: #{e.message}")
  end

  def self.vector_search_available?
    @vector_search_configured == true
  end
end
