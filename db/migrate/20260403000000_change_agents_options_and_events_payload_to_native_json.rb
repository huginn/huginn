class ChangeAgentsOptionsAndEventsPayloadToNativeJson < ActiveRecord::Migration[8.1]
  def up
    case ActiveRecord::Base.connection.adapter_name
    when /mysql/i
      normalize_blank_json_strings
      convert_service_options_to_json_strings

      change_column :agents, :options, :json
      change_column :agents, :memory, :json
      change_column :events, :payload, :json
      change_column :services, :options, :json
    when /postgres/i
      convert_service_options_to_json_strings

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

  def convert_service_options_to_json_strings
    each_service_option do |id, options|
      execute <<~SQL
        UPDATE services
        SET options = #{quote(JSON.dump(options))}
        WHERE id = #{id}
      SQL
    end
  end

  def each_service_option
    select_rows("SELECT id, options FROM services").each do |id, raw_options|
      yield id, parse_service_options(raw_options)
    end
  end

  def parse_service_options(raw_options)
    return {} if raw_options.blank?

    parsed =
      if raw_options.lstrip.start_with?("{", "[")
        JSON.parse(raw_options)
      else
        YAML.safe_load(raw_options, permitted_classes: [Symbol], aliases: true)
      end

    (parsed || {}).deep_stringify_keys
  rescue JSON::ParserError, Psych::Exception
    raise "Unable to convert services.options for native JSON storage"
  end
end
