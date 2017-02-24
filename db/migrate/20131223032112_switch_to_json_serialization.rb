class SwitchToJsonSerialization < ActiveRecord::Migration[4.2]
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
      %w[agent_logs agents delayed_jobs events links users].each do |table_name|
        quoted_table_name = ActiveRecord::Base.connection.quote_table_name(table_name)
        execute "ALTER TABLE #{quoted_table_name} CONVERT TO CHARACTER SET utf8"
      end
    end
  end

  def mysql?
    ActiveRecord::Base.connection.adapter_name =~ /mysql/i
  end

  def data_exists?
    events = ActiveRecord::Base.connection.select_rows("SELECT count(*) FROM #{ActiveRecord::Base.connection.quote_table_name("events")}").first.first.to_i
    agents = ActiveRecord::Base.connection.select_rows("SELECT count(*) FROM #{ActiveRecord::Base.connection.quote_table_name("agents")}").first.first.to_i
    agents + events > 0
  end

  def translate(from, to)
    FIELDS.each do |table, fields|
      quoted_table_name = ActiveRecord::Base.connection.quote_table_name(table)
      fields = fields.map { |f| ActiveRecord::Base.connection.quote_column_name(f) }

      page_start = 0
      page_size = 1000
      page_end = page_start + page_size

      begin
        rows = ActiveRecord::Base.connection.select_rows("SELECT id, #{fields.join(", ")} FROM #{quoted_table_name} WHERE id >= #{page_start} AND id < #{page_end}")
        puts "Grabbing rows of #{table} from #{page_start} to #{page_end}"
        rows.each do |row|
          id, *field_data = row

          yaml_fields = field_data.map { |f| from.load(f) }.map { |f| to.dump(f) }

          yaml_fields.map! {|f| f.encode('utf-8', 'binary', invalid: :replace, undef: :replace, replace: '??') }

          update_sql = "UPDATE #{quoted_table_name} SET #{fields.map {|f| "#{f}=?"}.join(", ")} WHERE id = ?"

          sanitized_update_sql = ActiveRecord::Base.send :sanitize_sql_array, [update_sql, *yaml_fields, id]

          ActiveRecord::Base.connection.execute sanitized_update_sql
        end
        page_start += page_size
        page_end += page_size

      end until rows.count == 0
    end

  end
end
