require 'rails_helper'

describe ScenarioImport do
  let(:user) { users(:bob) }
  let(:guid) { "somescenarioguid" }
  let(:tag_fg_color) { "#ffffff" }
  let(:tag_bg_color) { "#000000" }
  let(:icon) { 'Star' }
  let(:description) { "This is a cool Huginn Scenario that does something useful!" }
  let(:name) { "A useful Scenario" }
  let(:source_url) { "http://example.com/scenarios/2/export.json" }
  let(:weather_agent_options) {
    {
      'api_key' => 'some-api-key',
      'location' => '42.3601,-71.0589'
    }
  }
  let(:trigger_agent_options) {
    {
      'expected_receive_period_in_days' => 2,
      'rules' => [{
                    'type' => "regex",
                    'value' => "rain|storm",
                    'path' => "conditions",
                  }],
      'message' => "Looks like rain!"
    }
  }
  let(:valid_parsed_weather_agent_data) do
    {
      :type => "Agents::WeatherAgent",
      :name => "a weather agent",
      :schedule => "5pm",
      :keep_events_for => 14.days,
      :disabled => true,
      :guid => "a-weather-agent",
      :options => weather_agent_options
    }
  end
  let(:valid_parsed_trigger_agent_data) do
    {
      :type => "Agents::TriggerAgent",
      :name => "listen for weather",
      :keep_events_for => 0,
      :propagate_immediately => true,
      :disabled => false,
      :guid => "a-trigger-agent",
      :options => trigger_agent_options
    }
  end
  let(:valid_parsed_basecamp_agent_data) do
    {
      :type => "Agents::BasecampAgent",
      :name => "Basecamp test",
      :schedule => "every_2m",
      :keep_events_for => 0,
      :propagate_immediately => true,
      :disabled => false,
      :guid => "a-basecamp-agent",
      :options => {project_id: 12345}
    }
  end
  let(:valid_parsed_data) do
    {
      schema_version: 1,
      name: name,
      description: description,
      guid: guid,
      tag_fg_color: tag_fg_color,
      tag_bg_color: tag_bg_color,
      icon: icon,
      source_url: source_url,
      exported_at: 2.days.ago.utc.iso8601,
      agents: [
        valid_parsed_weather_agent_data,
        valid_parsed_trigger_agent_data
      ],
      links: [
        { :source => 0, :receiver => 1 }
      ],
      control_links: []
    }
  end
  let(:valid_data) { valid_parsed_data.to_json }
  let(:invalid_data) { { :name => "some scenario missing a guid" }.to_json }

  describe "initialization" do
    it "is initialized with an attributes hash" do
      expect(ScenarioImport.new(:url => "http://google.com").url).to eq("http://google.com")
    end
  end

  describe "validations" do
    subject do
      _import = ScenarioImport.new
      _import.set_user(user)
      _import
    end

    it "is not valid when none of file, url, or data are present" do
      expect(subject).not_to be_valid
      expect(subject).to have(1).error_on(:base)
      expect(subject.errors[:base]).to include("Please provide either a Scenario JSON File or a Public Scenario URL.")
    end

    describe "data" do
      it "should be invalid with invalid data" do
        subject.data = invalid_data
        expect(subject).not_to be_valid
        expect(subject).to have(1).error_on(:base)

        subject.data = "foo"
        expect(subject).not_to be_valid
        expect(subject).to have(1).error_on(:base)

        # It also clears the data when invalid
        expect(subject.data).to be_nil
      end

      it "should be valid with valid data" do
        subject.data = valid_data
        expect(subject).to be_valid
      end
    end

    describe "url" do
      it "should be invalid with an unreasonable URL" do
        subject.url = "foo"
        expect(subject).not_to be_valid
        expect(subject).to have(1).error_on(:url)
        expect(subject.errors[:url]).to include("appears to be invalid")
      end

      it "should be invalid when the referenced url doesn't contain a scenario" do
        stub_request(:get, "http://example.com/scenarios/1/export.json").to_return(:status => 200, :body => invalid_data)
        subject.url = "http://example.com/scenarios/1/export.json"
        expect(subject).not_to be_valid
        expect(subject.errors[:base]).to include("The provided data does not appear to be a valid Scenario.")
      end

      it "should be valid when the url points to a valid scenario" do
        stub_request(:get, "http://example.com/scenarios/1/export.json").to_return(:status => 200, :body => valid_data)
        subject.url = "http://example.com/scenarios/1/export.json"
        expect(subject).to be_valid
      end
    end

    describe "file" do
      it "should be invalid when the uploaded file doesn't contain a scenario" do
        subject.file = StringIO.new("foo")
        expect(subject).not_to be_valid
        expect(subject.errors[:base]).to include("The provided data does not appear to be a valid Scenario.")

        subject.file = StringIO.new(invalid_data)
        expect(subject).not_to be_valid
        expect(subject.errors[:base]).to include("The provided data does not appear to be a valid Scenario.")
      end

      it "should be valid with a valid uploaded scenario" do
        subject.file = StringIO.new(valid_data)
        expect(subject).to be_valid
      end
    end
  end

  describe "#dangerous?" do
    it "returns false on most Agents" do
      expect(ScenarioImport.new(:data => valid_data)).not_to be_dangerous
    end

    it "returns true if a ShellCommandAgent is present" do
      valid_parsed_data[:agents][0][:type] = "Agents::ShellCommandAgent"
      expect(ScenarioImport.new(:data => valid_parsed_data.to_json)).to be_dangerous
    end
  end

  describe "#import and #generate_diff" do
    let(:scenario_import) do
      _import = ScenarioImport.new(:data => valid_data)
      _import.set_user users(:bob)
      _import
    end

    context "when this scenario has never been seen before" do
      describe "#import" do
        it "makes a new scenario" do
          expect {
            scenario_import.import(:skip_agents => true)
          }.to change { users(:bob).scenarios.count }.by(1)

          expect(scenario_import.scenario.name).to eq(name)
          expect(scenario_import.scenario.description).to eq(description)
          expect(scenario_import.scenario.guid).to eq(guid)
          expect(scenario_import.scenario.tag_fg_color).to eq(tag_fg_color)
          expect(scenario_import.scenario.tag_bg_color).to eq(tag_bg_color)
          expect(scenario_import.scenario.icon).to eq(icon)
          expect(scenario_import.scenario.source_url).to eq(source_url)
          expect(scenario_import.scenario.public).to be_falsey
        end

        it "creates the Agents" do
          expect {
            scenario_import.import
          }.to change { users(:bob).agents.count }.by(2)

          weather_agent = scenario_import.scenario.agents.find_by(:guid => "a-weather-agent")
          trigger_agent = scenario_import.scenario.agents.find_by(:guid => "a-trigger-agent")

          expect(weather_agent.name).to eq("a weather agent")
          expect(weather_agent.schedule).to eq("5pm")
          expect(weather_agent.keep_events_for).to eq(14.days)
          expect(weather_agent.propagate_immediately).to be_falsey
          expect(weather_agent).to be_disabled
          expect(weather_agent.memory).to be_empty
          expect(weather_agent.options).to eq(weather_agent_options)

          expect(trigger_agent.name).to eq("listen for weather")
          expect(trigger_agent.sources).to eq([weather_agent])
          expect(trigger_agent.schedule).to be_nil
          expect(trigger_agent.keep_events_for).to eq(0)
          expect(trigger_agent.propagate_immediately).to be_truthy
          expect(trigger_agent).not_to be_disabled
          expect(trigger_agent.memory).to be_empty
          expect(trigger_agent.options).to eq(trigger_agent_options)
        end

        it "creates new Agents, even if one already exists with the given guid (so that we don't overwrite a user's work outside of the scenario)" do
          agents(:bob_weather_agent).update_attribute :guid, "a-weather-agent"

          expect {
            scenario_import.import
          }.to change { users(:bob).agents.count }.by(2)
        end

        context "when the schema_version is less than 1" do
          before do
            valid_parsed_weather_agent_data[:keep_events_for] = 2
            valid_parsed_data.delete(:schema_version)
          end

          it "translates keep_events_for from days to seconds" do
            scenario_import.import
            expect(scenario_import.errors).to be_empty
            weather_agent = scenario_import.scenario.agents.find_by(:guid => "a-weather-agent")
            trigger_agent = scenario_import.scenario.agents.find_by(:guid => "a-trigger-agent")

            expect(weather_agent.keep_events_for).to eq(2.days)
            expect(trigger_agent.keep_events_for).to eq(0)
          end
        end

        describe "with control links" do
          it 'creates the links' do
            valid_parsed_data[:control_links] = [
              { :controller => 1, :control_target => 0 }
            ]

            expect {
              scenario_import.import
            }.to change { users(:bob).agents.count }.by(2)

            weather_agent = scenario_import.scenario.agents.find_by(:guid => "a-weather-agent")
            trigger_agent = scenario_import.scenario.agents.find_by(:guid => "a-trigger-agent")

            expect(trigger_agent.sources).to eq([weather_agent])
            expect(weather_agent.controllers.to_a).to eq([trigger_agent])
            expect(trigger_agent.control_targets.to_a).to eq([weather_agent])
          end

          it "doesn't crash without any control links" do
            valid_parsed_data.delete(:control_links)

            expect {
              scenario_import.import
            }.to change { users(:bob).agents.count }.by(2)

            weather_agent = scenario_import.scenario.agents.find_by(:guid => "a-weather-agent")
            trigger_agent = scenario_import.scenario.agents.find_by(:guid => "a-trigger-agent")

            expect(trigger_agent.sources).to eq([weather_agent])
          end
        end
      end

      describe "#generate_diff" do
        it "returns AgentDiff objects for the incoming Agents" do
          expect(scenario_import).to be_valid

          agent_diffs = scenario_import.agent_diffs

          weather_agent_diff = agent_diffs[0]
          trigger_agent_diff = agent_diffs[1]

          valid_parsed_weather_agent_data.each do |key, value|
            if key == :type
              value = value.split("::").last
            end
            expect(weather_agent_diff).to respond_to(key)
            field = weather_agent_diff.send(key)
            expect(field).to be_a(ScenarioImport::AgentDiff::FieldDiff)
            expect(field.incoming).to eq(value)
            expect(field.updated).to eq(value)
            expect(field.current).to be_nil
          end
          expect(weather_agent_diff).not_to respond_to(:propagate_immediately)

          valid_parsed_trigger_agent_data.each do |key, value|
            if key == :type
              value = value.split("::").last
            end
            expect(trigger_agent_diff).to respond_to(key)
            field = trigger_agent_diff.send(key)
            expect(field).to be_a(ScenarioImport::AgentDiff::FieldDiff)
            expect(field.incoming).to eq(value)
            expect(field.updated).to eq(value)
            expect(field.current).to be_nil
          end
          expect(trigger_agent_diff).not_to respond_to(:schedule)
        end
      end
    end

    context "when an a scenario already exists with the given guid for the importing user" do
      let!(:existing_scenario) do
        _existing_scenerio = users(:bob).scenarios.build(:name => "an existing scenario", :description => "something")
        _existing_scenerio.guid = guid
        _existing_scenerio.save!

        agents(:bob_weather_agent).update_attribute :guid, "a-weather-agent"
        agents(:bob_weather_agent).scenarios << _existing_scenerio

        _existing_scenerio
      end

      describe "#import" do
        it "uses the existing scenario, updating its data" do
          expect {
            scenario_import.import(:skip_agents => true)
            expect(scenario_import.scenario).to eq(existing_scenario)
          }.not_to change { users(:bob).scenarios.count }

          existing_scenario.reload
          expect(existing_scenario.guid).to eq(guid)
          expect(existing_scenario.tag_fg_color).to eq(tag_fg_color)
          expect(existing_scenario.tag_bg_color).to eq(tag_bg_color)
          expect(existing_scenario.icon).to eq(icon)
          expect(existing_scenario.description).to eq(description)
          expect(existing_scenario.name).to eq(name)
          expect(existing_scenario.source_url).to eq(source_url)
          expect(existing_scenario.public).to be_falsey
        end

        it "updates any existing agents in the scenario, and makes new ones as needed" do
          expect(scenario_import).to be_valid

          expect {
            scenario_import.import
          }.to change { users(:bob).agents.count }.by(1) # One, because the weather agent already existed.

          weather_agent = existing_scenario.agents.find_by(:guid => "a-weather-agent")
          trigger_agent = existing_scenario.agents.find_by(:guid => "a-trigger-agent")

          expect(weather_agent).to eq(agents(:bob_weather_agent))

          expect(weather_agent.name).to eq("a weather agent")
          expect(weather_agent.schedule).to eq("5pm")
          expect(weather_agent.keep_events_for).to eq(14.days)
          expect(weather_agent.propagate_immediately).to be_falsey
          expect(weather_agent).to be_disabled
          expect(weather_agent.memory).to be_empty
          expect(weather_agent.options).to eq(weather_agent_options)

          expect(trigger_agent.name).to eq("listen for weather")
          expect(trigger_agent.sources).to eq([weather_agent])
          expect(trigger_agent.schedule).to be_nil
          expect(trigger_agent.keep_events_for).to eq(0)
          expect(trigger_agent.propagate_immediately).to be_truthy
          expect(trigger_agent).not_to be_disabled
          expect(trigger_agent.memory).to be_empty
          expect(trigger_agent.options).to eq(trigger_agent_options)
        end

        it "honors updates coming from the UI" do
          scenario_import.merges = {
            "0" => {
              "name" => "updated name",
              "schedule" => "6pm",
              "keep_events_for" => 2.days.to_i.to_s,
              "disabled" => "false",
              "options" => weather_agent_options.merge("api_key" => "foo").to_json
            }
          }

          expect(scenario_import).to be_valid

          expect(scenario_import.import).to be_truthy

          weather_agent = existing_scenario.agents.find_by(:guid => "a-weather-agent")
          expect(weather_agent.name).to eq("updated name")
          expect(weather_agent.schedule).to eq("6pm")
          expect(weather_agent.keep_events_for).to eq(2.days.to_i)
          expect(weather_agent).not_to be_disabled
          expect(weather_agent.options).to eq(weather_agent_options.merge("api_key" => "foo"))
        end

        it "adds errors when updated agents are invalid" do
          scenario_import.merges = {
            "0" => {
              "name" => "",
              "schedule" => "foo",
              "keep_events_for" => 2.days.to_i.to_s,
              "options" => weather_agent_options.merge("api_key" => "").to_json
            }
          }

          expect(scenario_import.import).to be_falsey

          errors = scenario_import.errors.full_messages.to_sentence
          expect(errors).to match(/Name can't be blank/)
          expect(errors).to match(/api_key is required/)
          expect(errors).to match(/Schedule is not a valid schedule/)
        end
      end

      describe "#generate_diff" do
        it "returns AgentDiff objects that include 'current' values from any agents that already exist" do
          agent_diffs = scenario_import.agent_diffs
          weather_agent_diff = agent_diffs[0]
          trigger_agent_diff = agent_diffs[1]

          # Already exists
          expect(weather_agent_diff.agent).to eq(agents(:bob_weather_agent))
          valid_parsed_weather_agent_data.each do |key, value|
            next if key == :type
            expect(weather_agent_diff.send(key).current).to eq(agents(:bob_weather_agent).send(key))
          end

          # Doesn't exist yet
          valid_parsed_trigger_agent_data.each do |key, value|
            expect(trigger_agent_diff.send(key).current).to be_nil
          end
        end

        context "when the schema_version is less than 1" do
          it "translates keep_events_for from days to seconds" do
            valid_parsed_data.delete(:schema_version)
            valid_parsed_data[:agents] = [valid_parsed_weather_agent_data.merge(keep_events_for: 5)]

            scenario_import.merges = {
              "0" => {
                "name" => "a new name",
                "schedule" => "6pm",
                "keep_events_for" => 2.days.to_i.to_s,
                "disabled" => "true",
                "options" => weather_agent_options.merge("api_key" => "foo").to_json
              }
            }

            expect(scenario_import).to be_valid

            weather_agent_diff = scenario_import.agent_diffs[0]

            expect(weather_agent_diff.name.current).to eq(agents(:bob_weather_agent).name)
            expect(weather_agent_diff.name.incoming).to eq('a weather agent')
            expect(weather_agent_diff.name.updated).to eq('a new name')
            expect(weather_agent_diff.keep_events_for.current).to eq(45.days.to_i)
            expect(weather_agent_diff.keep_events_for.incoming).to eq(5.days.to_i)
            expect(weather_agent_diff.keep_events_for.updated).to eq(2.days.to_i.to_s)
          end
        end

        it "sets the 'updated' FieldDiff values based on any feedback from the user" do
          scenario_import.merges = {
            "0" => {
              "name" => "a new name",
              "schedule" => "6pm",
              "keep_events_for" => 2.days.to_s,
              "disabled" => "true",
              "options" => weather_agent_options.merge("api_key" => "foo").to_json
            },
            "1" => {
              "name" => "another new name"
            }
          }

          expect(scenario_import).to be_valid

          agent_diffs = scenario_import.agent_diffs
          weather_agent_diff = agent_diffs[0]
          trigger_agent_diff = agent_diffs[1]

          expect(weather_agent_diff.name.current).to eq(agents(:bob_weather_agent).name)
          expect(weather_agent_diff.name.incoming).to eq(valid_parsed_weather_agent_data[:name])
          expect(weather_agent_diff.name.updated).to eq("a new name")

          expect(weather_agent_diff.schedule.updated).to eq("6pm")
          expect(weather_agent_diff.keep_events_for.current).to eq(45.days)
          expect(weather_agent_diff.keep_events_for.updated).to eq(2.days.to_s)
          expect(weather_agent_diff.disabled.updated).to eq("true")
          expect(weather_agent_diff.options.updated).to eq(weather_agent_options.merge("api_key" => "foo"))
        end

        it "adds errors on validation when updated options are unparsable" do
          scenario_import.merges = {
            "0" => {
              "options" => '{'
            }
          }
          expect(scenario_import).not_to be_valid
          expect(scenario_import).to have(1).error_on(:base)
        end
      end
    end

    context "when Bob imports Jane's scenario" do
      let!(:existing_scenario) do
        _existing_scenerio = users(:jane).scenarios.build(:name => "an existing scenario", :description => "something")
        _existing_scenerio.guid = guid
        _existing_scenerio.save!
        _existing_scenerio
      end

      describe "#import" do
        it "makes a new scenario for Bob" do
          expect {
            scenario_import.import(:skip_agents => true)
          }.to change { users(:bob).scenarios.count }.by(1)

          expect(Scenario.where(guid: guid).count).to eq(2)

          expect(scenario_import.scenario.name).to eq(name)
          expect(scenario_import.scenario.description).to eq(description)
          expect(scenario_import.scenario.guid).to eq(guid)
          expect(scenario_import.scenario.tag_fg_color).to eq(tag_fg_color)
          expect(scenario_import.scenario.tag_bg_color).to eq(tag_bg_color)
          expect(scenario_import.scenario.icon).to eq(icon)
          expect(scenario_import.scenario.source_url).to eq(source_url)
          expect(scenario_import.scenario.public).to be_falsey
        end

        it "does not change Jane's scenario" do
          expect {
            scenario_import.import(:skip_agents => true)
          }.not_to change { users(:jane).scenarios }
          expect(users(:jane).scenarios.find_by(guid: guid)).to eq(existing_scenario)
        end
      end
    end

    context "agents which require a service" do
      let(:valid_parsed_services) do
        data = valid_parsed_data
        data[:agents] = [valid_parsed_basecamp_agent_data,
                         valid_parsed_trigger_agent_data]
        data
      end

      let(:valid_parsed_services_data) { valid_parsed_services.to_json }

      let(:services_scenario_import) {
        _import = ScenarioImport.new(:data => valid_parsed_services_data)
        _import.set_user users(:bob)
        _import
      }

      describe "#generate_diff" do
        it "should check if the agent requires a service" do
          agent_diffs = services_scenario_import.agent_diffs
          basecamp_agent_diff = agent_diffs[0]
          expect(basecamp_agent_diff.requires_service?).to eq(true)
        end

        it "should add an error when no service is selected" do
          expect(services_scenario_import.import).to eq(false)
          expect(services_scenario_import.errors[:base].length).to eq(1)
        end
      end

      describe "#import" do
        it "should import" do
          services_scenario_import.merges = {
            "0" => {
              "service_id" => "0",
            }
          }
          expect {
            expect(services_scenario_import.import).to eq(true)
          }.to change { users(:bob).agents.count }.by(2)
        end
      end
    end
  end
end
