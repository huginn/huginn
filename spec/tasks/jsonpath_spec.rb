require "rails_helper"
require "rake"

describe "agents:migrate_jsonpaths" do # rubocop:disable Metrics/BlockLength
  around do |example|
    previous = Rake.application
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load Rails.root.join("lib/tasks/jsonpath.rake")
    example.run
  ensure
    Rake.application = previous
  end

  let(:task) { Rake::Task["agents:migrate_jsonpaths"] }
  let(:agent) { agents(:bob_rain_notifier_agent) }

  it "preserves legacy choices by default and can recheck them on a later run" do
    agent.update_columns(options: { "rules" => [{ "path" => "title" }], "use_legacy_jsonpath" => true })
    expect { task.invoke }.to output(/User ##{agent.user_id}:/).to_stdout
    expect(agent.reload.options["use_legacy_jsonpath"]).to eq(true)

    task.reenable
    expect { task.invoke("true") }.to output(/Updated JSONPath options/).to_stdout
    expect(agent.reload.options).to eq("rules" => [{ "path" => "$.title" }])
  end

  it "keeps uncertain expressions on legacy and preserves an explicit RFC choice" do
    agent.update_columns(options: { "rules" => [{ "path" => "$.items.first" }], "use_legacy_jsonpath" => true })
    other = agents(:jane_rain_notifier_agent)
    other.update_columns(options: { "rules" => [{ "path" => "$.items.first" }], "use_legacy_jsonpath" => false })

    expect { task.invoke("true") }.to output(/Updated JSONPath options/).to_stdout
    expect(agent.reload.options["use_legacy_jsonpath"]).to eq(true)
    expect(other.reload.options["use_legacy_jsonpath"]).to eq(false)
  end

  it "rejects a mistyped recheck argument before making changes" do
    original = agent.options.deep_dup
    expect {
      expect { task.invoke("treu") }.to raise_error(SystemExit)
    }.to output("recheck_legacy must be true or false\n").to_stderr
    expect(agent.reload.options).to eq(original)
  end
end
