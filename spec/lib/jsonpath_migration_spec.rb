require "rails_helper"
require "jsonpath_migration"

describe JsonpathMigration do # rubocop:disable Metrics/BlockLength
  describe JsonpathMigration::Path do # rubocop:disable Metrics/BlockLength
    it "normalizes roots and names without changing legacy lookup results" do # rubocop:disable Metrics/BlockLength
      paths = {
        "title" => "$.title",
        ".nested.title" => "$.nested.title",
        "$.nested['title']" => "$.nested.title",
        "-nonexistent-" => '$["-nonexistent-"]',
        "0" => '$["0"]',
        '$["a.b"]' => '$["a.b"]',
        "items[*].title" => "$.items[*].title",
        "items[0].title" => "$.items[0].title",
        "items[-1].title" => "$.items[-1].title",
        "" => "$",
        "." => "$",
        "$" => "$",
        "escape nested.title" => "escape $.nested.title",
      }
      data = {
        "title" => "hello world", "nested" => { "title" => "nested" },
        "items" => [{ "title" => "one" }, { "title" => "two" }],
        "-nonexistent-" => false, "0" => nil, "a.b" => 3,
      }

      paths.each do |old, normalized|
        result = described_class.normalize(old)
        expect(result.value).to eq(normalized)
        expect(Utils.values_at(data, old, legacy: true)).to eq(Utils.values_at(data, normalized, legacy: true))
        expect(described_class.normalize(normalized).value).to eq(normalized)
      end
    end

    it "leaves filters and other complex or malformed expressions for manual review" do
      [
        "[?(@.name>0)].name", "$.items[?(@.n == 2)]", "$.items[?(@.flag)]",
        "$.items[?(@.name =~ /abc/)]", "$.items[(@.length-1)]",
        "$.items[::-1]", "$..title", "items.*.title", "$.items[0,1]",
        '$["a\\nb"]', "$.items[", "!", "$.items[9007199254740992]",
        "{{ path }}", "$.{% if enabled %}title{% endif %}", nil, 5,
        "$.text.downcase", "$.items.length", "size", "$['empty?']",
      ].each do |path|
        result = described_class.normalize(path)
        expect(result.value).to eq(path)
        expect(result.review_reason).to be_present
      end
    end

    it "does not declare array selectors semantically compatible with RFC 9535" do
      result = described_class.normalize("items[-1].title")

      expect(result.value).to eq("$.items[-1].title")
      expect(result.review_reason).to include("input types and index bounds")
      expect(described_class.normalize("$.title").review_reason).to be_nil
    end

    it "preserves results across both engines for automatically migrated selectors" do
      ["", ".", "title", ".nested.title", "0", "-nonexistent-", '$["a.b"]'].each do |path|
        result = described_class.normalize(path)
        expect(result.review_reason).to be_nil
        inputs = [nil, false, 42, "text", [], [{ "title" => 1 }], {},
                  { "title" => false, "nested" => { "title" => nil }, "0" => 3, "a.b" => [] }]
        inputs.each do |data|
          json = JSON.generate(data)
          expect(Utils.values_at(json, result.value, legacy: false)).to eq(Utils.values_at(json, path, legacy: true))
        end
      end
    end
  end

  describe "data migration" do # rubocop:disable Metrics/BlockLength
    let(:migration) { described_class.new }
    let(:agent) { agents(:bob_rain_notifier_agent) }

    before do
      allow(migration).to receive(:say)
      allow(Rails.application.config.action_mailer).to receive(:default_url_options)
        .and_return(host: "huginn.example", port: 8443, script_name: "/huginn")
      allow(Rails.application.config).to receive(:force_ssl).and_return(true)
    end

    it "updates only known JSONPath fields without callbacks or timestamp changes" do
      original_time = agent.updated_at
      original_jobs = Delayed::Job.count
      options = {
        "rules" => [
          { "path" => "title", "value" => "untouched", "type" => "regex" },
          { "path" => "$.items[?(@.n == 2)]", "value" => "private-value" },
          "{{ enabled }}",
        ],
        "message" => "title", "other" => { "path" => "title" },
      }
      agent.update_columns(options: options, disabled: true)

      migration.run

      expected = options.deep_dup
      expected["use_legacy_jsonpath"] = true
      expect(agent.reload.options).to eq(expected)
      expect(agent.updated_at).to eq(original_time)
      expect(agent.disabled).to eq(true)
      expect(Delayed::Job.count).to eq(original_jobs)
      expect(migration).to have_received(:say)
        .with("User ##{agent.user_id}:\nhttps://huginn.example:8443/huginn/agents/#{agent.id}")
      expect(migration).not_to have_received(:say).with(/private-value|@\.n|rules\[/)
    end

    it "normalizes website JSON extraction paths without touching XPath or templates" do
      website = agents(:bob_website_agent)
      website.update_columns(options: {
        "type" => "json",
        "extract" => {
          "title" => { "path" => "items[*].title", "repeat" => true },
          "version" => { "path" => "[?(@.name>0)].name" },
          "other" => { "xpath" => ".//title", "value" => "." },
        },
        "template" => { "path" => "{{ title }}" },
      })

      migration.run

      expect(website.reload.options["extract"]).to eq({
        "title" => { "path" => "items[*].title", "repeat" => true },
        "version" => { "path" => "[?(@.name>0)].name" },
        "other" => { "xpath" => ".//title", "value" => "." },
      })
      expect(website.options["template"]).to eq("path" => "{{ title }}")
      expect(website.options["use_legacy_jsonpath"]).to eq(true)
      expect(migration).to have_received(:say)
        .with("User ##{website.user_id}:\nhttps://huginn.example:8443/huginn/agents/#{website.id}").once
      expect(migration).not_to have_received(:say).with(/extract|@\.name/)
    end

    it "preserves blank optional paths but normalizes an empty webhook payload path" do
      agent.update_columns(type: "Agents::PeakDetectorAgent",
                           options: { "value_path" => "count", "group_by_path" => "" })
      webhook = agents(:bob_website_agent)
      webhook.update_columns(type: "Agents::WebhookAgent", options: { "payload_path" => "", "secret" => "untouched" })

      migration.run

      expect(Agent.find(agent.id).options).to eq("value_path" => "$.count", "group_by_path" => "")
      expect(Agent.find(webhook.id).options).to eq("payload_path" => "$", "secret" => "untouched")
    end

    it "ignores unrelated agent settings and is idempotent" do
      agent.update_columns(options: { "rules" => [{ "path" => "title" }] })
      other = agents(:bob_website_agent)
      other.update_columns(type: "Agents::LocalFileAgent", options: { "path" => "some/file" })

      migration.run
      first = agent.reload.options.deep_dup
      migration.run

      expect(agent.reload.options).to eq(first)
      expect(Agent.find(other.id).options).to eq("path" => "some/file")
    end

    it "preserves explicit dialect choices and keeps legacy Agents unchanged on reruns" do
      agent.update_columns(options: { "rules" => [{ "path" => "title" }], "use_legacy_jsonpath" => true })
      original = agent.reload.options.deep_dup
      migration.run
      migration.run
      expect(agent.reload.options).to eq(original)

      agent.update_columns(options: { "rules" => [{ "path" => "$[?(@.n == 2)]" }], "use_legacy_jsonpath" => false })
      original = agent.reload.options.deep_dup
      migration.run
      expect(agent.reload.options).to eq(original)
    end

    it "keeps possible method references on the legacy engine" do
      agent.update_columns(options: { "rules" => [{ "path" => "text.strip.downcase" }] })
      migration.run
      expect(agent.reload.options).to eq({
        "rules" => [{ "path" => "text.strip.downcase" }], "use_legacy_jsonpath" => true,
      })
    end

    it "also reads and writes JSON through a legacy text attribute" do
      connection = ActiveRecord::Base.connection
      connection.create_table(:jsonpath_legacy_agents, temporary: true) do |table|
        table.string :type
        table.integer :user_id
        table.text :options
      end
      legacy_agent = Class.new(ActiveRecord::Base) do
        self.table_name = "jsonpath_legacy_agents"
        self.inheritance_column = nil
      end
      stub_const("JsonpathMigration::MigrationAgent", legacy_agent)
      record = legacy_agent.create!(
        type: "Agents::TriggerAgent", user_id: agent.user_id,
        options: JSON.generate({ "rules" => [{ "path" => "title" }], "secret" => "unchanged" })
      )

      expect(record.reload.options).to be_a(String)
      migration.run

      expect(JSON.parse(record.reload.options)).to eq({
        "rules" => [{ "path" => "$.title" }], "secret" => "unchanged",
      })
    ensure
      connection.drop_table(:jsonpath_legacy_agents, if_exists: true)
    end

    it "groups private review URLs by user and lists each Agent only once" do
      targets = [agent, agents(:bob_website_agent), agents(:jane_rain_notifier_agent)]
      targets.each do |target|
        target.update_columns(type: "Agents::TriggerAgent", name: "private-agent-name", options: {
          "rules" => [{ "path" => "$.private[?(@.n == 2)]" }, { "path" => "{{ private_path }}" }],
          "secret" => "private-value",
        })
      end

      migration.run

      targets.group_by(&:user_id).each do |user_id, owned_agents|
        urls = owned_agents.map(&:id).sort.map { |id| "https://huginn.example:8443/huginn/agents/#{id}" }
        expect(migration).to have_received(:say).with("User ##{user_id}:\n#{urls.join("\n")}").once
      end
      expect(migration).not_to have_received(:say).with(/private|@\.n/)
    end

    it "falls back to relative links when a public host is not configured" do
      allow(Rails.application.config.action_mailer).to receive(:default_url_options).and_return({})
      agent.update_columns(options: { "rules" => [{ "path" => "$.items[?(@.flag)]" }] })

      migration.run

      expect(migration).to have_received(:say).with("User ##{agent.user_id}:\n/agents/#{agent.id}")
      expect(migration).to have_received(:say).with(/DOMAIN is not configured/)
    end

    it "stops without exposing options if an Agent cannot store the legacy flag" do
      options = ["private-value"]
      unless [:json, :jsonb].include?(described_class::MigrationAgent.type_for_attribute("options").type)
        options = JSON.generate(options)
      end
      described_class::MigrationAgent.find(agent.id).update_columns(options: options)

      expect { migration.run }.to raise_error(ActiveRecord::MigrationError, /Agent ##{agent.id} has invalid options/)
      expect(migration).not_to have_received(:say).with(/private-value/)
    end
  end
end
