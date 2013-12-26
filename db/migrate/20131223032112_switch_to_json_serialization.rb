class SwitchToJsonSerialization < ActiveRecord::Migration
  FIELDS = {
    :agents => [:options, :memory],
    :events => [:payload]
  }

  def up
    if data_exists?
      puts "This migration will update tables to use UTF-8 encoding and will update Agent and Event storage from YAML to JSON."
      puts "It should work, but please make a backup before proceeding!"
      print "Continue? (y/n) "
      STDOUT.flush
      exit unless STDIN.gets =~ /^y/i

      set_to_utf8
      translate YAML, JSON
    end
  end

  def down
    if data_exists?
      translate JSON, YAML
    end
  end

  def set_to_utf8
    if mysql?
      %w[agent_logs agents delayed_jobs events links taggings tags users].each do |table_name|
        quoted_table_name = ActiveRecord::Base.connection.quote_table_name(table_name)
        execute "ALTER TABLE #{quoted_table_name} CONVERT TO CHARACTER SET utf8"
      end
    end
  end

  def mysql?
    ActiveRecord::Base.connection.adapter_name =~ /mysql/i
  end

  def data_exists?
    events = ActiveRecord::Base.connection.select_rows("SELECT count(*) FROM #{ActiveRecord::Base.connection.quote_table_name("events")}").first.first
    agents = ActiveRecord::Base.connection.select_rows("SELECT count(*) FROM #{ActiveRecord::Base.connection.quote_table_name("agents")}").first.first
    agents + events > 0
  end

  def translate(from, to)
    FIELDS.each do |table, fields|
      quoted_table_name = ActiveRecord::Base.connection.quote_table_name(table)
      fields = fields.map { |f| ActiveRecord::Base.connection.quote_column_name(f) }

      rows = ActiveRecord::Base.connection.select_rows("SELECT id, #{fields.join(", ")} FROM #{quoted_table_name}")
      rows.each do |row|
        id, *field_data = row

        yaml_fields = field_data.map { |f| from.load(f) }.map { |f| to.dump(f) }

        yaml_fields.map! {|f| f.encode('utf-8', 'binary', invalid: :replace, undef: :replace, replace: '??') }

        update_sql = "UPDATE #{quoted_table_name} SET #{fields.map {|f| "#{f}=?"}.join(", ")} WHERE id = ?"

        sanitized_update_sql = ActiveRecord::Base.send :sanitize_sql_array, [update_sql, *yaml_fields, id]

        ActiveRecord::Base.connection.execute sanitized_update_sql
      end
    end

  end
end
