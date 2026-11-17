# frozen_string_literal: true

require "date"
require "fileutils"
require "json"
require "net/http"
require "nokogiri"
require "time"

module ContainerDownloads
  IMAGES = {
    "ghcr.io/huginn/huginn" => "https://github.com/huginn/huginn/pkgs/container/huginn",
    "ghcr.io/huginn/huginn-single-process" => "https://github.com/huginn/huginn/pkgs/container/huginn-single-process",
    "ghcr.io/huginn/huginn-test" => "https://github.com/huginn/huginn/pkgs/container/huginn-test",
    "docker.io/huginn/huginn" => "https://hub.docker.com/v2/namespaces/huginn/repositories/huginn",
    "docker.io/huginn/huginn-single-process" => "https://hub.docker.com/v2/namespaces/huginn/repositories/huginn-single-process"
  }.freeze

  class Error < StandardError; end

  class Client
    RETRYABLE = [408, 429, 500, 502, 503, 504].freeze

    def get(url)
      uri = URI(url)
      3.times do |attempt|
        begin
          response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
            request = Net::HTTP::Get.new(uri)
            request["User-Agent"] = "Huginn container download statistics"
            request["Accept-Language"] = "en"
            http.request(request)
          end
          return response.body if response.code == "200"

          raise Error, "#{url}: HTTP #{response.code}" unless RETRYABLE.include?(response.code.to_i) && attempt < 2

          retry_after = response["Retry-After"]
          delay = retry_after&.match?(/\A\d+\z/) ? [retry_after.to_i, 60].min : 2**attempt
        rescue IOError, SystemCallError, SocketError, Timeout::Error, Net::HTTPBadResponse, OpenSSL::SSL::SSLError => e
          raise Error, "#{url}: #{e.class}" if attempt == 2

          delay = 2**attempt
        end
        warn "#{url}: retrying in #{delay}s"
        sleep delay
      end
    end
  end

  def self.ghcr_count(html)
    document = Nokogiri::HTML(html)
    labels = document.css("span").select { |node| node.text.strip == "Total downloads" }
    counts = labels.filter_map do |label|
      count = label.next_element
      count["title"] if count&.name == "h3"
    end
    unless counts.one? && counts.first.match?(/\A(?:\d+|\d{1,3}(?:,\d{3})+)\z/)
      raise Error, "GHCR page has no unique exact Total downloads count"
    end

    Integer(counts.first.delete(","), 10)
  end

  def self.docker_count(json, image)
    data = JSON.parse(json)
    namespace, name = image.delete_prefix("docker.io/").split("/", 2)
    unless data.is_a?(Hash) && data["namespace"] == namespace && data["name"] == name &&
           data["pull_count"].is_a?(Integer) && data["pull_count"] >= 0
      raise Error, "Docker Hub response has no valid pull_count for #{image}"
    end

    data.fetch("pull_count")
  rescue JSON::ParserError
    raise Error, "Docker Hub returned invalid JSON for #{image}"
  end

  def self.collect(client: Client.new, clock: -> { Time.now.utc })
    images = IMAGES.to_h do |image, url|
      body = client.get(url)
      count = image.start_with?("ghcr.io/") ? ghcr_count(body) : docker_count(body, image)
      [image, { "count" => count, "source" => url }]
    rescue Error => e
      raise Error, "#{image}: #{e.message}"
    end
    { "schema_version" => 1, "collected_at" => clock.call.utc.iso8601(6), "images" => images }
  end

  def self.validate(record)
    unless record.is_a?(Hash) && record["schema_version"] == 1 &&
           record["collected_at"].is_a?(String) && record["collected_at"].end_with?("Z") &&
           record["images"].is_a?(Hash) && record["images"].keys.sort == IMAGES.keys.sort
      raise Error, "Invalid statistics record"
    end
    Time.iso8601(record.fetch("collected_at"))
    record.fetch("images").each do |image, value|
      unless value.is_a?(Hash) && value["count"].is_a?(Integer) && value["count"] >= 0 && value["source"] == IMAGES.fetch(image)
        raise Error, "Invalid counter for #{image}"
      end
    end
    record
  rescue ArgumentError
    raise Error, "Invalid collection timestamp"
  end

  def self.history(directory)
    Dir.glob(File.join(directory, "records", "*.json")).map do |path|
      validate(JSON.parse(File.read(path)))
    end.sort_by { |record| Time.iso8601(record.fetch("collected_at")) }
  end

  def self.period(records, image, days)
    last_time = Time.iso8601(records.last.fetch("collected_at"))
    cutoff = last_time - days * 86_400
    baseline = records.rindex { |record| Time.iso8601(record.fetch("collected_at")) <= cutoff }
    return nil unless baseline

    interval = records[baseline..]
    reset = interval.each_cons(2).any? { |a, b| b.fetch("images").fetch(image).fetch("count") < a.fetch("images").fetch(image).fetch("count") }
    missing_days = interval.each_cons(2).sum do |a, b|
      [(Date.iso8601(b.fetch("collected_at")) - Date.iso8601(a.fetch("collected_at"))).to_i - 1, 0].max
    end
    first = interval.first
    {
      "requested_days" => days,
      "from" => first.fetch("collected_at"),
      "to" => records.last.fetch("collected_at"),
      "elapsed_seconds" => (last_time - Time.iso8601(first.fetch("collected_at"))).to_i,
      "missing_days" => missing_days,
      "counter_decreased" => reset,
      "downloads" => reset ? nil : records.last.fetch("images").fetch(image).fetch("count") - first.fetch("images").fetch(image).fetch("count")
    }
  end

  def self.summary(records)
    latest = records.last
    {
      "schema_version" => 1,
      "collected_at" => latest.fetch("collected_at"),
      "total" => latest.fetch("images").values.sum { |value| value.fetch("count") },
      "images" => IMAGES.to_h do |image, _url|
        [image, {
          "count" => latest.fetch("images").fetch(image).fetch("count"),
          "periods" => [1, 7, 30].to_h { |days| [days.to_s, period(records, image, days)] }
        }]
      end
    }
  end

  def self.badge(total, timestamp)
    label = "container downloads"
    value = total.to_s.reverse.scan(/.{1,3}/).join(",").reverse
    left_width = label.length * 7 + 12
    right_width = value.length * 7 + 12
    width = left_width + right_width
    Nokogiri::XML::Builder.new do |xml|
      xml.svg(xmlns: "http://www.w3.org/2000/svg", width: width, height: 20, role: "img", "aria-label": "#{label}: #{value}") do
        xml.title "#{label}: #{value} (#{timestamp})"
        xml.rect(width: left_width, height: 20, fill: "#555")
        xml.rect(x: left_width, width: right_width, height: 20, fill: "#007ec6")
        xml.g(fill: "#fff", "text-anchor": "middle", "font-family": "Verdana,DejaVu Sans,sans-serif", "font-size": 11) do
          xml.text_(label, x: left_width / 2, y: 14)
          xml.text_(value, x: left_width + right_width / 2, y: 14)
        end
      end
    end.to_xml
  end

  def self.write_json(path, data)
    File.write(path, "#{JSON.pretty_generate(data)}\n")
  end

  def self.store(record, directory)
    validate(record)
    records = history(directory)
    if records.any? && Time.iso8601(record.fetch("collected_at")) <= Time.iso8601(records.last.fetch("collected_at"))
      raise Error, "Collection timestamp must be newer than the last record"
    end
    records << record
    report = summary(records)
    svg = badge(report.fetch("total"), report.fetch("collected_at"))
    FileUtils.mkdir_p(File.join(directory, "records"))
    filename = Time.iso8601(record.fetch("collected_at")).utc.strftime("%Y-%m-%dT%H%M%S%6NZ.json")
    path = File.join(directory, "records", filename)
    File.open(path, File::WRONLY | File::CREAT | File::EXCL) { |file| file.write("#{JSON.pretty_generate(record)}\n") }
    write_json(File.join(directory, "latest.json"), record)
    write_json(File.join(directory, "summary.json"), report)
    File.write(File.join(directory, "badge.svg"), svg)
  end
end
