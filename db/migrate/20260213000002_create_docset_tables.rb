class CreateDocsetTables < ActiveRecord::Migration[7.0]
  def change
    create_table :docsets do |t|
      t.string   :name,            null: false
      t.string   :display_name,    null: false
      t.string   :version
      t.string   :source,          null: false, default: 'official'
      t.string   :feed_url
      t.string   :identifier,      null: false
      t.string   :platform_family
      t.string   :status,          null: false, default: 'pending'
      t.text     :error_message
      t.integer  :entry_count,     default: 0
      t.integer  :chunk_count,     default: 0
      t.integer  :page_count,      default: 0

      t.timestamps
    end

    add_index :docsets, :name, unique: true
    add_index :docsets, :identifier, unique: true
    add_index :docsets, :status

    create_table :docset_pages do |t|
      t.references :docset, null: false, foreign_key: true
      t.string     :path,   null: false
      t.string     :title
      t.string     :entry_type
      t.text       :html_content, limit: 16_777_215  # MEDIUMTEXT on MySQL
      t.text       :text_content, limit: 16_777_215

      t.timestamps
    end

    add_index :docset_pages, [:docset_id, :path], unique: true
    add_index :docset_pages, [:docset_id, :entry_type]

    create_table :docset_chunks do |t|
      t.references :docset,      null: false, foreign_key: true
      t.references :docset_page, null: false, foreign_key: true
      t.string     :entry_name
      t.string     :entry_type
      t.text       :content,     null: false
      t.integer    :chunk_index, default: 0
      t.integer    :token_count, default: 0

      t.timestamps
    end

    add_index :docset_chunks, [:docset_id, :entry_type]
    add_index :docset_chunks, [:docset_id, :entry_name]

    # Add vector column only on PostgreSQL with pgvector
    if postgresql? && extension_enabled?('vector')
      dims = Remix::Docset::EmbeddingClient.dimensions
      add_column :docset_chunks, :embedding, :vector, limit: dims
      add_index :docset_chunks, :embedding, using: :hnsw, opclass: :vector_cosine_ops, name: 'index_docset_chunks_on_embedding'
    end
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
  end
end
