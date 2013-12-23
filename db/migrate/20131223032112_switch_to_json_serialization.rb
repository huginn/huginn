class SwitchToJsonSerialization < ActiveRecord::Migration
  FIELDS = {
    :agents => [:options, :memory],
    :events => [:payload]
  }

  def up
    puts "This migration will update Agent and Event storage from YAML to JSON.  It should work, but please make a backup"
    puts "before proceeding."
    print "Continue? (y/n) "
    STDOUT.flush
    exit unless STDIN.gets =~ /^y/i

    translate YAML, JSON
  end

  def down
    translate JSON, YAML
  end

  def translate(from, to)
    FIELDS.each do |table, fields|
      quoted_table_name = ActiveRecord::Base.connection.quote_table_name(table)
      fields = fields.map { |f| ActiveRecord::Base.connection.quote_column_name(f) }

      rows = ActiveRecord::Base.connection.select_rows("SELECT id, #{fields.join(", ")} FROM #{quoted_table_name}")
      rows.each do |row|
        id, *field_data = row

        yaml_fields = field_data.map { |f| from.load(f) }.map { |f| to.dump(f) }

        update_sql = "UPDATE #{quoted_table_name} SET #{fields.map {|f| "#{f}=?"}.join(", ")} WHERE id = ?"

        sanitized_update_sql = ActiveRecord::Base.send :sanitize_sql_array, [update_sql, *yaml_fields, id]

        ActiveRecord::Base.connection.execute sanitized_update_sql
      end
    end

  end
end
