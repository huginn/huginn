require "rails_helper"

describe "Liquid tokenizer quoted strings" do
  it "parses a well-formed quoted path without hanging" do
    parsed = Timeout.timeout(1) { Liquid::Template.parse("{{ data['some text'] }}") }

    variable = parsed.root.nodelist.first
    expect(variable).to be_a(Liquid::Variable)
    expect(variable.name.name).to eq("data")
    expect(variable.name.lookups).to eq(["some text"])
  end

  it "parses a quoted path containing an extra single quote without hanging" do
    source = "{{ data['I'm using another single quote'] }}"

    parsed = Timeout.timeout(1) { Liquid::Template.parse(source) }

    expect(parsed).to be_a(Liquid::Template)
  end

  it "parses JSON containing a quoted path with an apostrophe without hanging" do
    source = {
      "a" => {
        "type" => "text",
        "value" => "{{ data['I'm using another single quote'] }}"
      },
      "b" => {
        "type" => "text",
        "value" => "{{ data['some text'] }}"
      }
    }.to_json

    parsed = Timeout.timeout(1) { Liquid::Template.parse(source) }

    expect(parsed).to be_a(Liquid::Template)
  end

  it "does not terminate a variable early on a brace inside a quoted filter argument" do
    parsed = Timeout.timeout(1) {
      Liquid::Template.parse("{{ message | replace: '{name}', customer_name }}")
    }

    expect(parsed.root.nodelist.first).to be_a(Liquid::Variable)
  end
end
