# Select the JSONPath dialect consistently for Agent validation and execution.
module JsonpathEvaluation
  extend ActiveSupport::Concern

  PATH_OPTIONS = {
    "Agents::AttributeDifferenceAgent" => %w[path],
    "Agents::CsvAgent" => %w[data_path],
    "Agents::GapDetectorAgent" => %w[value_path],
    "Agents::PeakDetectorAgent" => %w[value_path group_by_path],
    "Agents::SentimentAgent" => %w[content],
    "Agents::WebhookAgent" => %w[payload_path],
    "Agents::WeiboPublishAgent" => %w[message_path pic_path],
  }.freeze

  included do
    validate :validate_jsonpath_options
  end

  def use_legacy_jsonpath?
    boolify(options["use_legacy_jsonpath"])
  end

  def values_at(data, path)
    Utils.values_at(data, path, legacy: use_legacy_jsonpath?)
  end

  def value_at(data, path)
    values_at(data, path).first
  end

  private

  def each_jsonpath_option
    case self.class.name
    when "Agents::TriggerAgent"
      Array(options["rules"]).each do |rule|
        yield rule["path"] if rule.is_a?(Hash)
      end
    when "Agents::WebsiteAgent"
      return unless options["extract"].is_a?(Hash)

      options["extract"].each_value do |details|
        yield details["path"] if details.is_a?(Hash) && details.key?("path")
      end
    else
      PATH_OPTIONS.fetch(self.class.name, []).each do |key|
        yield options[key] if options.key?(key)
      end
    end
  end

  def validate_jsonpath_options
    if options.key?("use_legacy_jsonpath") && boolify(options["use_legacy_jsonpath"]).nil?
      errors.add(:base, "use_legacy_jsonpath must be true or false")
    end
    return if use_legacy_jsonpath?

    each_jsonpath_option do |path|
      next if path.blank? && self.class.name != "Agents::WebhookAgent"
      next if path in /\{[{%]/

      begin
        raise ArgumentError unless path.is_a?(String)

        Janeway.parse(path.delete_prefix("escape "))
      rescue ArgumentError, Janeway::Error
        errors.add(:base, "JSONPath must use RFC 9535 syntax")
      end
    end
  end
end
