class RenameDigestEmailToEmailDigest < ActiveRecord::Migration[4.2]
  def up
    sql = <<-SQL
      UPDATE #{ActiveRecord::Base.connection.quote_table_name('agents')}
      SET #{ActiveRecord::Base.connection.quote_column_name('type')} = 'Agents::EmailDigestAgent'
      WHERE #{ActiveRecord::Base.connection.quote_column_name('type')} = 'Agents::DigestEmailAgent'
    SQL

    execute sql
  end

  def down
    sql = <<-SQL
      UPDATE #{ActiveRecord::Base.connection.quote_table_name('agents')}
      SET #{ActiveRecord::Base.connection.quote_column_name('type')} = 'Agents::DigestEmailAgent'
      WHERE #{ActiveRecord::Base.connection.quote_column_name('type')} = 'Agents::EmailDigestAgent'
    SQL

    execute sql
  end
end
