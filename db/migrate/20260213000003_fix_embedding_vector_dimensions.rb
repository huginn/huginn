class FixEmbeddingVectorDimensions < ActiveRecord::Migration[7.0]
  def up
    return unless postgresql? && extension_enabled?('vector')
    return unless column_exists?(:docset_chunks, :embedding)

    dims = Remix::Docset::EmbeddingClient.dimensions

    # Check current column definition — skip if already correct
    current_col = columns(:docset_chunks).find { |c| c.name == 'embedding' }
    current_limit = current_col&.limit
    return if current_limit == dims

    # Drop the HNSW index first (if it exists)
    if index_exists?(:docset_chunks, :embedding, name: 'index_docset_chunks_on_embedding')
      remove_index :docset_chunks, name: 'index_docset_chunks_on_embedding'
    end

    # Clear any existing embeddings (they were generated with wrong dimensions)
    execute "UPDATE docset_chunks SET embedding = NULL"

    # Reset any docsets that failed due to dimension mismatch so they can be retried
    execute "UPDATE docsets SET status = 'pending', error_message = NULL WHERE status = 'error'"

    # Recreate column with correct dimensions
    remove_column :docset_chunks, :embedding
    add_column :docset_chunks, :embedding, :vector, limit: dims

    # Recreate the HNSW index
    add_index :docset_chunks, :embedding, using: :hnsw, opclass: :vector_cosine_ops, name: 'index_docset_chunks_on_embedding'
  end

  def down
    return unless postgresql? && extension_enabled?('vector')
    return unless column_exists?(:docset_chunks, :embedding)

    if index_exists?(:docset_chunks, :embedding, name: 'index_docset_chunks_on_embedding')
      remove_index :docset_chunks, name: 'index_docset_chunks_on_embedding'
    end

    remove_column :docset_chunks, :embedding
    add_column :docset_chunks, :embedding, :vector, limit: 1536
    add_index :docset_chunks, :embedding, using: :hnsw, opclass: :vector_cosine_ops, name: 'index_docset_chunks_on_embedding'
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
  end
end
