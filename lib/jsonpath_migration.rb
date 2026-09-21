require "json"
require "jsonpath"

# Switch only provably compatible paths; retain the legacy evaluator otherwise.
class JsonpathMigration # rubocop:disable Metrics/ClassLength
  PATH_OPTIONS = {
    "Agents::AttributeDifferenceAgent" => %w[path],
    "Agents::CsvAgent" => %w[data_path],
    "Agents::GapDetectorAgent" => %w[value_path],
    "Agents::PeakDetectorAgent" => %w[value_path group_by_path],
    "Agents::SentimentAgent" => %w[content],
    "Agents::WebhookAgent" => %w[payload_path],
    "Agents::WeiboPublishAgent" => %w[message_path pic_path],
  }.freeze

  # Avoid loading Agent subclasses or running their scheduling callbacks.
  class MigrationAgent < ActiveRecord::Base
    self.table_name = "agents"
    self.inheritance_column = nil
  end

  # Use the legacy tokenizer to preserve its interpretation of names.  Only
  # accept a small selector subset; never evaluate a saved expression or guess
  # the meaning of filters, scripts, escaped names, or Liquid templates.
  class Path
    Result = Struct.new(:value, :review_reason)

    def self.normalize(value)
      return Result.new(value, "non-string path") unless value.is_a?(String)
      return Result.new(value, "dynamic Liquid expression") if value.match?(/\{[{%]/)

      prefix = value.start_with?("escape ") ? "escape " : ""
      tokens = JsonPath.new(value.delete_prefix(prefix)).path
      tokens.shift if tokens.first == "$"
      result = "$"
      review_reason = nil

      tokens.each do |token|
        case token
        when /\A\[(?:'([^'"\\\[\],\p{Cntrl}]*)'|"([^'"\\\[\],\p{Cntrl}]*)")\]\z/
          name = Regexp.last_match(1) || Regexp.last_match(2)
          if %w[downcase upcase strip length size empty? present? blank? first last].include?(name)
            return Result.new(value, "possible legacy method reference")
          end

          result << (name.match?(/\A[A-Za-z_][A-Za-z0-9_]*\z/) ? ".#{name}" : "[#{JSON.generate(name)}]")
        when "[*]", /\A\[(?:0|-?[1-9][0-9]*)\]\z/
          if token != "[*]" && token[1...-1].to_i.abs > 9_007_199_254_740_991
            return Result.new(value, "index outside the RFC integer range")
          end

          result << token
          review_reason = "array selectors: check input types and index bounds before opting into RFC 9535"
        else
          return Result.new(value, "complex expression: check filter coercion, existence tests, and selector semantics")
        end
      end

      Result.new(prefix + result, review_reason)
    rescue ArgumentError, NoMethodError
      Result.new(value, "unrecognized legacy syntax")
    end
  end

  def initialize(output: $stdout.method(:puts), recheck_legacy: false)
    @output = output
    @recheck_legacy = recheck_legacy
  end

  def run
    native_json = [:json, :jsonb].include?(MigrationAgent.type_for_attribute("options").type)
    changed = 0
    review = Hash.new { |users, id| users[id] = [] }

    MigrationAgent.where(type: PATH_OPTIONS.keys + %w[Agents::TriggerAgent Agents::WebsiteAgent]).find_each do |agent|
      agent.with_lock do
        options = parse_options(agent.options)
        unless options.is_a?(Hash)
          raise ActiveRecord::MigrationError, "Agent ##{agent.id} has invalid options; cannot set JSONPath dialect"
        end

        if preserve_dialect?(options)
          review[agent.user_id] << agent.id if [true, "true"].include?(options["use_legacy_jsonpath"])
          next
        end

        original = options
        options = migrated_options(agent.type, original)
        review[agent.user_id] << agent.id if options["use_legacy_jsonpath"]
        next if options == original

        agent.update_columns(options: native_json ? options : JSON.generate(options))
        changed += 1
      end
    end

    say "Updated JSONPath options on #{changed} Agents; #{review.values.sum(&:size)} Agents retain legacy JSONPath."
    report_review_urls(review)
  end

  private

  def preserve_dialect?(options)
    return false unless options.key?("use_legacy_jsonpath")
    return true unless @recheck_legacy

    ![true, "true"].include?(options["use_legacy_jsonpath"])
  end

  def say(message)
    @output.call(message)
  end

  def migrated_options(type, original)
    options = original.deep_dup
    each_path(type, options) do |container, key|
      next unless container.key?(key)
      next if container[key].blank? && (
        type == "Agents::GapDetectorAgent" ||
        (type == "Agents::PeakDetectorAgent" && key == "group_by_path")
      )

      result = Path.normalize(container[key])
      return original.merge("use_legacy_jsonpath" => true) if result.review_reason

      container[key] = result.value
    end
    options.except("use_legacy_jsonpath")
  end

  def parse_options(value)
    return {} if value.nil? || (value.is_a?(String) && value.strip.empty?)

    parsed = value.is_a?(String) ? JSON.parse(value) : value
    parsed.nil? ? {} : parsed
  rescue JSON::ParserError
    nil
  end

  def report_review_urls(review)
    return if review.empty?

    url_options = Rails.application.config.action_mailer.default_url_options.to_h.symbolize_keys
    url_options[:protocol] = "https" if Rails.application.config.force_ssl
    if url_options[:host].blank?
      url_options[:only_path] = true
      say "DOMAIN is not configured; reporting relative Agent URLs."
    end
    routes = Rails.application.routes.url_helpers
    review.sort_by { |user_id, _ids| user_id.to_i }.each do |user_id, ids|
      urls = ids.map { |id| routes.agent_url(id, **url_options) }
      say "User ##{user_id}:\n#{urls.join("\n")}"
    end
  end

  def each_path(type, options)
    case type
    when "Agents::TriggerAgent"
      return unless options["rules"].is_a?(Array)

      options["rules"].each do |rule|
        yield rule, "path" if rule.is_a?(Hash)
      end
    when "Agents::WebsiteAgent"
      return unless options["extract"].is_a?(Hash)

      options["extract"].each_value do |details|
        yield details, "path" if details.is_a?(Hash)
      end
    else
      PATH_OPTIONS.fetch(type).each do |key|
        yield options, key
      end
    end
  end
end
