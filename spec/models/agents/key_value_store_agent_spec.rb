require "rails_helper"

describe Agents::KeyValueStoreAgent do
  let(:value_template) { "{{ _event_ | as_object }}" }

  let(:agent) do
    Agents::KeyValueStoreAgent.create!(
      name: "somename",
      options: {
        key: "{{ id }}",
        value: value_template,
        variable: "kvs",
        max_keys: 3,
      },
      user: users(:jane)
    )
  end

  let(:source_agent) do
    agents(:jane_weather_agent)
  end

  def create_event(payload)
    source_agent.events.create!(payload:)
  end

  let(:events) do
    [
      create_event({ id: 1, name: "foo" }),
      create_event({ id: 2, name: "bar" }),
      create_event({ id: 3, name: "baz" }),
      create_event({ id: 1, name: "FOO" }),
      create_event({ id: 4, name: "quux" }),
    ]
  end

  describe "validation" do
    before do
      expect(agent).to be_valid
    end

    it "should validate key" do
      # empty key is OK
      agent.options[:key] = ""
      expect(agent).to be_valid

      agent.options.delete(:key)
      expect(agent).not_to be_valid
    end

    it "should validate value" do
      agent.options[:value] = ""
      expect(agent).to be_valid

      agent.options.delete(:value)
      expect(agent).not_to be_valid
    end

    it "should validate variable" do
      agent.options[:variable] = "1abc"
      expect(agent).not_to be_valid

      agent.options[:variable] = ""
      expect(agent).not_to be_valid

      agent.options[:variable] = {}
      expect(agent).not_to be_valid

      agent.options.delete(:variable)
      expect(agent).not_to be_valid
    end

    it "should validate max_keys" do
      agent.options.delete(:max_keys)
      expect(agent).to be_valid
      expect(agent.max_keys).to eq 100

      agent.options[:max_keys] = 0
      expect(agent).not_to be_valid
    end
  end

  describe "#receive" do
    it "receives and updates the storage" do
      agent.receive(events[0..2])

      expect(agent.reload.memory).to match(
        {
          "1" => { id: 1, name: "foo" },
          "2" => { id: 2, name: "bar" },
          "3" => { id: 3, name: "baz" },
        }
      )

      agent.receive([events[3]])

      expect(agent.reload.memory).to match(
        {
          "1" => { id: 1, name: "FOO" },
          "2" => { id: 2, name: "bar" },
          "3" => { id: 3, name: "baz" },
        }
      )

      agent.receive([events[4]])

      # The key "bar" should have been removed because it is the oldest.
      expect(agent.reload.memory).to match(
        {
          "1" => { id: 1, name: "FOO" },
          "3" => { id: 3, name: "baz" },
          "4" => { id: 4, name: "quux" },
        }
      )
    end

    describe "empty value" do
      let(:value_template) { "{{ name | as_object }}" }

      it "deletes the key" do
        agent.receive(events[0..2])

        expect(agent.reload.memory).to match(
          {
            "1" => "foo",
            "2" => "bar",
            "3" => "baz",
          }
        )

        agent.receive([create_event({ id: 1, name: "" })])

        expect(agent.reload.memory).to match(
          {
            "2" => "bar",
            "3" => "baz",
          }
        )

        agent.receive([create_event({ id: 2, name: [] })])

        expect(agent.reload.memory).to match(
          {
            "3" => "baz",
          }
        )

        agent.receive([create_event({ id: 3, name: {} })])

        expect(agent.reload.memory).to eq({})
      end
    end

    describe "using _value_" do
      let(:value_template) { "{% if _value_ %}{{ _value_ }}, {% endif %}{{ name }}" }

      it "represents the existing value" do
        agent.receive(events[0..2])

        expect(agent.reload.memory).to match(
          {
            "1" => "foo",
            "2" => "bar",
            "3" => "baz",
          }
        )

        agent.receive([events[3]])

        expect(agent.reload.memory).to match(
          {
            "1" => "foo, FOO",
            "2" => "bar",
            "3" => "baz",
          }
        )
      end
    end
  end

  describe "control target" do
    let(:value_template) { "{{ name }}" }

    before do
      agent.receive(events[0..2])
    end

    let!(:target_agent) do
      agents(:jane_website_agent).tap { |target_agent|
        target_agent.options[:url] = "https://example.com/{{ kvs['3'] }}"
        target_agent.controllers << agent
        target_agent.save!
      }
    end

    it "can refer to the storage" do
      expect(target_agent.interpolated[:url]).to eq "https://example.com/baz"
    end
  end
end
