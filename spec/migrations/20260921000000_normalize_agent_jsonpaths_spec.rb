require "rails_helper"
require Rails.root.join("db/migrate/20260921000000_normalize_agent_jsonpaths")

describe NormalizeAgentJsonpaths do
  it "runs the shared migration and preserves the result on rollback" do
    agent = agents(:bob_rain_notifier_agent)
    agent.update_columns(options: { "rules" => [{ "path" => "title" }] })
    migration = described_class.new
    allow(migration).to receive(:say)

    migration.up
    migration.down

    expect(agent.reload.options).to eq("rules" => [{ "path" => "$.title" }])
  end
end
