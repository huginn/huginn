# Converts legacy YAML-serialized service options into JSON strings.
class ConvertServiceOptionsToJsonSerialization < ActiveRecord::Migration[8.1]
  def up
    return if native_json_column?

    each_service_option do |id, raw_options|
      update_service_options(id, JSON.dump(parse_yaml_or_json(raw_options)))
    end
  end

  def down
    return if native_json_column?

    each_service_option do |id, raw_options|
      update_service_options(id, YAML.dump(parse_json(raw_options)))
    end
  end

  private

  def each_service_option(&block)
    select_rows("SELECT id, options FROM services").each do |id, raw_options|
      block.call(id, raw_options)
    end
  end

  def update_service_options(id, options)
    execute(ActiveRecord::Base.send(:sanitize_sql_array, [
      "UPDATE services SET options = ? WHERE id = ?",
      options,
      id,
    ]))
  end

  def native_json_column?
    [:json, :jsonb].include?(connection.columns(:services).find { |column| column.name == "options" }&.type)
  end

  def parse_yaml_or_json(raw_options)
    return {} if raw_options.blank?

    parsed =
      if raw_options.lstrip.start_with?("{", "[")
        JSON.parse(raw_options)
      else
        YAML.safe_load(raw_options, permitted_classes: [Symbol], aliases: true)
      end

    (parsed || {}).deep_stringify_keys
  rescue JSON::ParserError, Psych::Exception
    raise "Unable to convert services.options to JSON serialization"
  end

  def parse_json(raw_options)
    return {} if raw_options.blank?

    parsed = JSON.parse(raw_options)
    (parsed || {}).deep_stringify_keys
  rescue JSON::ParserError
    raise "Unable to convert services.options to YAML serialization"
  end
end
