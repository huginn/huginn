require "spec_helper"
require "tmpdir"
require "rake"
require_relative "../../lib/container_downloads"

describe ContainerDownloads do
  def snapshot(date, count = 100)
    {
      "schema_version" => 1,
      "collected_at" => "#{date}T02:23:00.000000Z",
      "images" => described_class::IMAGES.to_h { |image, url| [image, { "count" => count, "source" => url }] }
    }
  end

  let(:image) { described_class::IMAGES.keys.first }

  describe ".ghcr_count" do
    it "reads the exact title, including entities and nested labels, instead of the rounded display or version count" do
      html = '<h3 title="99">Version downloads</h3><span><b>Total downloads</b></span> <!-- count --> <h3 class="count" title="1&#44;234&#44;567">1.23M</h3>'
      expect(described_class.ghcr_count(html)).to eq(1_234_567)
    end

    it "accepts an explicit zero" do
      expect(described_class.ghcr_count('<span>Total downloads</span><h3 title="0">0</h3>')).to eq(0)
    end

    it "rejects missing, rounded, negative, malformed and ambiguous counts" do
      ["", '<span>Total downloads</span><h3>1.2M</h3>',
       '<span>Total downloads</span><h3 title="1.2M">1.2M</h3>',
       '<span>Total downloads</span><h3 title="-1">-1</h3>',
       '<span>Total downloads</span><h3 title="1,23">123</h3>',
       '<span>Total downloads</span><h3 title="1">1</h3>' * 2].each do |html|
        expect { described_class.ghcr_count(html) }.to raise_error(described_class::Error)
      end
    end
  end

  describe ".docker_count" do
    let(:docker_image) { "docker.io/huginn/huginn" }
    let(:response) { { namespace: "huginn", name: "huginn", pull_count: 123 } }

    it "reads a nonnegative integer for the requested repository" do
      expect(described_class.docker_count(response.to_json, docker_image)).to eq(123)
      expect(described_class.docker_count(response.merge(pull_count: 0).to_json, docker_image)).to eq(0)
    end

    it "rejects unavailable, invalid and unrelated counters" do
      ["not json", "null", response.except(:pull_count).to_json,
       response.merge(pull_count: "123").to_json, response.merge(pull_count: -1).to_json,
       response.merge(name: "other").to_json].each do |json|
        expect { described_class.docker_count(json, docker_image) }.to raise_error(described_class::Error)
      end
    end
  end

  describe ".collect" do
    let(:client) { instance_double(described_class::Client) }

    it "records all five sources with a UTC timestamp" do
      described_class::IMAGES.each do |name, url|
        body = if name.start_with?("ghcr.io/")
                 '<span>Total downloads</span><h3 title="123">123</h3>'
               else
                 { namespace: "huginn", name: name.split("/").last, pull_count: 456 }.to_json
               end
        allow(client).to receive(:get).with(url).and_return(body)
      end
      result = described_class.collect(client: client, clock: -> { Time.iso8601("2026-01-01T11:23:00+09:00") })
      expect(result["collected_at"]).to eq("2026-01-01T02:23:00.000000Z")
      expect(result["images"].values.map { |value| value["count"] }).to eq([123, 123, 123, 456, 456])
    end

    it "fails the entire snapshot when one source is unavailable" do
      allow(client).to receive(:get).and_return("<html>unavailable</html>")
      expect { described_class.collect(client: client) }.to raise_error(described_class::Error, /ghcr.io\/huginn\/huginn/)
    end
  end

  describe ContainerDownloads::Client do
    let(:client) { described_class.new }
    let(:url) { "https://example.com/counter" }

    def response(status, body = "ok", headers = {})
      double(code: status, body: body, :[] => headers["Retry-After"])
    end

    it "retries transient HTTP failures and bounds Retry-After" do
      allow(Net::HTTP).to receive(:start).and_return(response("429", "", "Retry-After" => "999"), response("503"), response("200"))
      expect(client).to receive(:sleep).with(60).ordered
      expect(client).to receive(:sleep).with(2).ordered
      expect(client.get(url)).to eq("ok")
    end

    it "reports an exhausted network failure without returning zero" do
      allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout)
      allow(client).to receive(:sleep)
      expect { client.get(url) }.to raise_error(ContainerDownloads::Error, /example.com.*Net::ReadTimeout/)
      expect(Net::HTTP).to have_received(:start).exactly(3).times
    end

    it "recovers from a transient DNS failure" do
      attempts = 0
      allow(Net::HTTP).to receive(:start) do
        attempts += 1
        raise SocketError if attempts == 1

        response("200")
      end
      expect(client).to receive(:sleep).with(1)
      expect(client.get(url)).to eq("ok")
    end

    it "does not retry permanent failures or follow redirects to unrelated pages" do
      expect(client).not_to receive(:sleep)
      ["404", "302"].each do |status|
        allow(Net::HTTP).to receive(:start).and_return(response(status))
        expect { client.get(url) }.to raise_error(ContainerDownloads::Error, /HTTP #{status}/)
      end
    end
  end

  describe ".store" do
    it "preserves snapshots including same-day runs and regenerates valid summaries and SVG" do
      Dir.mktmpdir do |directory|
        first = snapshot("2026-01-01")
        described_class.store(first, directory)
        second = snapshot("2026-01-01", 110)
        second["collected_at"] = "2026-01-01T03:23:00.000000Z"
        described_class.store(second, directory)
        expect(described_class.history(directory)).to eq([first, second])
        expect(JSON.parse(File.read(File.join(directory, "latest.json")))).to eq(second)
        expect(JSON.parse(File.read(File.join(directory, "summary.json")))["total"]).to eq(550)
        svg = Nokogiri::XML(File.read(File.join(directory, "badge.svg"))) { |config| config.strict }
        expect(svg.at_css("svg")["aria-label"]).to include("550")
        expect(svg.css("text").map(&:text)).to eq(["container downloads", "550"])
      end
    end

    it "rejects incomplete and older snapshots without changing history" do
      Dir.mktmpdir do |directory|
        described_class.store(snapshot("2026-01-02"), directory)
        invalid = snapshot("2026-01-03")
        invalid["images"].delete(image)
        [invalid, snapshot("2026-01-01"), snapshot("2026-01-02")].each do |record|
          expect { described_class.store(record, directory) }.to raise_error(described_class::Error)
        end
        expect(described_class.history(directory)).to eq([snapshot("2026-01-02")])
      end
    end
  end

  describe ".period" do
    it "reports actual elapsed time and missing dates rather than inventing daily counts" do
      records = [snapshot("2026-01-01"), snapshot("2026-01-03", 140)]
      result = described_class.period(records, image, 1)
      expect(result).to include("downloads" => 40, "missing_days" => 1, "elapsed_seconds" => 172_800, "counter_decreased" => false)
      expect(described_class.period(records, image, 7)).to be_nil
    end

    it "calculates daily, weekly and rolling 30-day differences" do
      records = [snapshot("2026-01-01", 10), snapshot("2026-01-24", 30), snapshot("2026-01-30", 40), snapshot("2026-01-31", 50)]
      expect([1, 7, 30].map { |days| described_class.period(records, image, days)["downloads"] }).to eq([10, 20, 40])
    end

    it "flags decreases inside the window even when the counter later exceeds its baseline" do
      records = [snapshot("2026-01-01", 100), snapshot("2026-01-02", 5), snapshot("2026-01-03", 110)]
      expect(described_class.period(records, image, 2)).to include("counter_decreased" => true, "downloads" => nil)
      expect(described_class.period(records, image, 1)).to include("counter_decreased" => false, "downloads" => 105)
    end
  end

  describe "Rake tasks" do
    around do |example|
      original = Rake.application
      Rake.application = Rake::Application.new
      load File.expand_path("../../lib/tasks/stats.rake", __dir__)
      example.run
    ensure
      Rake.application = original
    end

    it "collects a snapshot and records it without loading Rails" do
      record = snapshot("2026-01-01")
      allow(described_class).to receive(:collect).and_return(record)
      Dir.mktmpdir do |directory|
        path = File.join(directory, "snapshot.json")
        output = File.join(directory, "history")
        Rake::Task["stats:containers:collect"].invoke(path)
        Rake::Task["stats:containers:record"].invoke(path, output)
        expect(described_class.history(output)).to eq([record])
      end
    end

    it "rejects missing task arguments before collecting or writing" do
      expect(described_class).not_to receive(:collect)
      expect(described_class).not_to receive(:store)
      %w[stats:containers:collect stats:containers:record].each do |name|
        expect { Rake::Task[name].invoke }.to raise_error(SystemExit)
      end
    end
  end
end
