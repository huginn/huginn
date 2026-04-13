# Optionally upgrades serialized text columns to native JSON column types.
class ChangeAgentsOptionsAndEventsPayloadToNativeJson < ActiveRecord::Migration[8.1]
  def up
    return unless ENV["NATIVE_JSON_COLUMNS"].present?

    case ActiveRecord::Base.connection.adapter_name
    when /mysql/i
      normalize_blank_json_strings

      change_column :agents, :options, :json
      change_column :agents, :memory, :json
      change_column :events, :payload, :json
      change_column :services, :options, :json
    when /postgres/i
      change_column :agents, :options, :jsonb,
                    using: "CASE WHEN options IS NULL OR btrim(options) = '' THEN '{}'::jsonb ELSE options::jsonb END"
      change_column :agents, :memory, :jsonb,
                    using: "CASE WHEN memory IS NULL OR btrim(memory) = '' THEN '{}'::jsonb ELSE memory::jsonb END"
      change_column :events, :payload, :jsonb,
                    using: "CASE WHEN payload IS NULL OR btrim(payload) = '' THEN '{}'::jsonb ELSE payload::jsonb END"
      change_column :services, :options, :jsonb,
                    using: "CASE WHEN options IS NULL OR btrim(options) = '' THEN '{}'::jsonb ELSE options::jsonb END"
    else
      raise NotImplementedError, "Unsupported adapter: #{ActiveRecord::Base.connection.adapter_name}"
    end
  end

  def down
    return unless native_json_columns?

    case ActiveRecord::Base.connection.adapter_name
    when /mysql/i
      change_column :agents, :options, :text
      change_column :agents, :memory, :text, limit: 4.gigabytes - 1
      change_column :events, :payload, :text, limit: 16.megabytes - 1
      change_column :services, :options, :text
    when /postgres/i
      change_column :agents, :options, :text, using: "options::text"
      change_column :agents, :memory, :text, using: "memory::text"
      change_column :events, :payload, :text, using: "payload::text"
      change_column :services, :options, :text, using: "options::text"
    else
      raise NotImplementedError, "Unsupported adapter: #{ActiveRecord::Base.connection.adapter_name}"
    end
  end

  private

  def native_json_columns?
    {
      agents: [:options, :memory],
      events: [:payload],
      services: [:options],
    }.all? do |table, columns|
      columns.all? do |column|
        [:json, :jsonb].include?(column_type(table, column))
      end
    end
  end

  def column_type(table, column)
    connection.columns(table).find { |candidate| candidate.name == column.to_s }&.type
  end

  def normalize_blank_json_strings
    execute <<~SQL
      UPDATE agents
      SET options = '{}'
      WHERE options IS NULL OR TRIM(options) = ''
    SQL

    execute <<~SQL
      UPDATE agents
      SET memory = '{}'
      WHERE memory IS NULL OR TRIM(memory) = ''
    SQL

    execute <<~SQL
      UPDATE events
      SET payload = '{}'
      WHERE payload IS NULL OR TRIM(payload) = ''
    SQL
  end
end
