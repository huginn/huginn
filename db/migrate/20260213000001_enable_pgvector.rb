class EnablePgvector < ActiveRecord::Migration[7.0]
  def up
    return unless postgresql?

    begin
      enable_extension 'vector' unless extension_enabled?('vector')
    rescue ActiveRecord::StatementInvalid => e
      # pgvector extension is not installed on this PostgreSQL server — skip gracefully.
      # Docset embedding features will use keyword search fallback instead of vector search.
      Rails.logger.warn("pgvector extension not available: #{e.message}. Vector search will be disabled.")
    end
  end

  def down
    return unless postgresql?

    begin
      disable_extension 'vector' if extension_enabled?('vector')
    rescue ActiveRecord::StatementInvalid
      # Extension was never enabled
    end
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
  end
end
