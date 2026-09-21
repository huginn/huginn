require "rails_helper"

describe JsonpathEvaluation do # rubocop:disable Metrics/BlockLength
  let(:agent) { agents(:bob_rain_notifier_agent) }

  it "defaults to RFC semantics and switches coercion and existence tests per Agent" do
    data = [{ "n" => "2", "flag" => false }, { "n" => 2 }]
    expect(agent.values_at(data, "$[?(@.n == 2)]")).to eq([data.last])
    expect(agent.values_at(data, "$[?(@.flag)]")).to eq([data.first])

    agent.options["use_legacy_jsonpath"] = true
    expect(agent.values_at(data, "$[?(@.n == 2)]")).to eq(data)
    expect(agent.values_at(data, "$[?(@.flag)]")).to eq([])
    expect(agents(:jane_rain_notifier_agent).values_at(data, "$[?(@.n == 2)]")).to eq([data.last])
  end

  it "validates RFC syntax unless legacy mode is explicitly enabled" do
    agent.options["rules"][0]["path"] = "temperature"
    expect(agent).not_to be_valid
    expect(agent.errors[:base]).to include("JSONPath must use RFC 9535 syntax")
    expect { agent.value_at({}, "temperature") }.to raise_error(Janeway::Error)

    [true, "true"].each do |flag|
      agent.options["use_legacy_jsonpath"] = flag
      expect(agent).to be_valid
      expect(agent.value_at({ temperature: 20 }, "temperature")).to eq(20)
    end
    [false, "false"].each do |flag|
      agent.options["use_legacy_jsonpath"] = flag
      expect(agent).not_to be_valid
    end
  end

  it "rejects nonboolean flags and invalid RFC function arguments" do
    agent.options["use_legacy_jsonpath"] = "{{ legacy }}"
    expect(agent).not_to be_valid
    expect(agent.errors[:base]).to include("use_legacy_jsonpath must be true or false")
    agent.options.delete("use_legacy_jsonpath")
    agent.options["rules"][0]["path"] = "$[?length(@.*) > 0]"
    expect(agent).not_to be_valid
  end

  it "defers Liquid paths to runtime, where RFC validation still applies" do
    agent.options["rules"][0]["path"] = "{{ path }}"
    expect(agent).to be_valid
    expect { agent.value_at({}, "title") }.to raise_error(Janeway::Error)
  end

  it "normalizes JSON inputs and preserves escaping without modifying the expression" do
    [false, true].each do |legacy|
      agent.options["use_legacy_jsonpath"] = legacy
      path = "escape $.title".freeze
      expect(agent.value_at({ title: "hello world" }, path)).to eq("hello+world")
      expect(agent.value_at('{"title":null}', "$.title")).to be_nil
      expect(agent.values_at({}, "$.missing")).to eq([])
      expect(agent.values_at("false", "$")).to eq([false])
    end
  end

  it "uses the selected dialect when a TriggerAgent receives an event" do
    agent.options["rules"] = [{ "type" => "field>=value", "value" => "2", "path" => "$.items[?(@.n == 2)].n" }]
    event = Event.new(payload: { "items" => [{ "n" => "2" }] })
    expect { agent.receive([event]) }.not_to change(Event, :count)

    agent.options["use_legacy_jsonpath"] = true
    expect { agent.receive([event]) }.to change(Event, :count).by(1)
  end
end
