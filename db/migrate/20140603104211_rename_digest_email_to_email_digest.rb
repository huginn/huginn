class RenameDigestEmailToEmailDigest < ActiveRecord::Migration
  def up
    sql = <<-SQL
      UPDATE #{ActiveRecord::Base.connection.quote_table_name('agents')}
      SET #{ActiveRecord::Base.connection.quote_column_name('type')} = "EmailDigestAgent"
      WHERE #{ActiveRecord::Base.connection.quote_column_name('type')} = "DigestEmailAgent"
    SQL

    execute sql
  end

  def down
    sql = <<-SQL
      UPDATE #{ActiveRecord::Base.connection.quote_table_name('agents')}
      SET #{ActiveRecord::Base.connection.quote_column_name('type')} = "DigestEmailAgent"
      WHERE #{ActiveRecord::Base.connection.quote_column_name('type')} = "EmailDigestAgent"
    SQL

    execute sql
  end
end
