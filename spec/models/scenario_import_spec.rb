require 'spec_helper'

describe ScenarioImport do
  let(:user) { users(:bob) }
  let(:guid) { "somescenarioguid" }
  let(:tag_fg_color) { "#ffffff" }
  let(:tag_bg_color) { "#000000" }
  let(:description) { "This is a cool Huginn Scenario that does something useful!" }
  let(:name) { "A useful Scenario" }
  let(:source_url) { "http://example.com/scenarios/2/export.json" }
  let(:weather_agent_options) {
    {
      'api_key' => 'some-api-key',
      'location' => '12345'
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
      :keep_events_for => 14,
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
      :name => name,
      :description => description,
      :guid => guid,
      :tag_fg_color => tag_fg_color,
      :tag_bg_color => tag_bg_color,
      :source_url => source_url,
      :exported_at => 2.days.ago.utc.iso8601,
      :agents => [
        valid_parsed_weather_agent_data,
        valid_parsed_trigger_agent_data
      ],
      :links => [
        { :source => 0, :receiver => 1 }
      ]
    }
  end
  let(:valid_data) { valid_parsed_data.to_json }
  let(:invalid_data) { { :name => "some scenario missing a guid" }.to_json }

  describe "initialization" do
    it "is initialized with an attributes hash" do
      ScenarioImport.new(:url => "http://google.com").url.should == "http://google.com"
    end
  end

  describe "validations" do
    subject do
      _import = ScenarioImport.new
      _import.set_user(user)
      _import
    end

    it "is not valid when none of file, url, or data are present" do
      subject.should_not be_valid
      subject.should have(1).error_on(:base)
      subject.errors[:base].should include("Please provide either a Scenario JSON File or a Public Scenario URL.")
    end

    describe "data" do
      it "should be invalid with invalid data" do
        subject.data = invalid_data
        subject.should_not be_valid
        subject.should have(1).error_on(:base)

        subject.data = "foo"
        subject.should_not be_valid
        subject.should have(1).error_on(:base)

        # It also clears the data when invalid
        subject.data.should be_nil
      end

      it "should be valid with valid data" do
        subject.data = valid_data
        subject.should be_valid
      end
    end

    describe "url" do
      it "should be invalid with an unreasonable URL" do
        subject.url = "foo"
        subject.should_not be_valid
        subject.should have(1).error_on(:url)
        subject.errors[:url].should include("appears to be invalid")
      end

      it "should be invalid when the referenced url doesn't contain a scenario" do
        stub_request(:get, "http://example.com/scenarios/1/export.json").to_return(:status => 200, :body => invalid_data)
        subject.url = "http://example.com/scenarios/1/export.json"
        subject.should_not be_valid
        subject.errors[:base].should include("The provided data does not appear to be a valid Scenario.")
      end

      it "should be valid when the url points to a valid scenario" do
        stub_request(:get, "http://example.com/scenarios/1/export.json").to_return(:status => 200, :body => valid_data)
        subject.url = "http://example.com/scenarios/1/export.json"
        subject.should be_valid
      end
    end

    describe "file" do
      it "should be invalid when the uploaded file doesn't contain a scenario" do
        subject.file = StringIO.new("foo")
        subject.should_not be_valid
        subject.errors[:base].should include("The provided data does not appear to be a valid Scenario.")

        subject.file = StringIO.new(invalid_data)
        subject.should_not be_valid
        subject.errors[:base].should include("The provided data does not appear to be a valid Scenario.")
      end

      it "should be valid with a valid uploaded scenario" do
        subject.file = StringIO.new(valid_data)
        subject.should be_valid
      end
    end
  end

  describe "#dangerous?" do
    it "returns false on most Agents" do
      ScenarioImport.new(:data => valid_data).should_not be_dangerous
    end

    it "returns true if a ShellCommandAgent is present" do
      valid_parsed_data[:agents][0][:type] = "Agents::ShellCommandAgent"
      ScenarioImport.new(:data => valid_parsed_data.to_json).should be_dangerous
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
          lambda {
            scenario_import.import(:skip_agents => true)
          }.should change { users(:bob).scenarios.count }.by(1)

          scenario_import.scenario.name.should == name
          scenario_import.scenario.description.should == description
          scenario_import.scenario.guid.should == guid
          scenario_import.scenario.tag_fg_color.should == tag_fg_color
          scenario_import.scenario.tag_bg_color.should == tag_bg_color
          scenario_import.scenario.source_url.should == source_url
          scenario_import.scenario.public.should be_falsey
        end

        it "creates the Agents" do
          lambda {
            scenario_import.import
          }.should change { users(:bob).agents.count }.by(2)

          weather_agent = scenario_import.scenario.agents.find_by(:guid => "a-weather-agent")
          trigger_agent = scenario_import.scenario.agents.find_by(:guid => "a-trigger-agent")

          weather_agent.name.should == "a weather agent"
          weather_agent.schedule.should == "5pm"
          weather_agent.keep_events_for.should == 14
          weather_agent.propagate_immediately.should be_falsey
          weather_agent.should be_disabled
          weather_agent.memory.should be_empty
          weather_agent.options.should == weather_agent_options

          trigger_agent.name.should == "listen for weather"
          trigger_agent.sources.should == [weather_agent]
          trigger_agent.schedule.should be_nil
          trigger_agent.keep_events_for.should == 0
          trigger_agent.propagate_immediately.should be_truthy
          trigger_agent.should_not be_disabled
          trigger_agent.memory.should be_empty
          trigger_agent.options.should == trigger_agent_options
        end

        it "creates new Agents, even if one already exists with the given guid (so that we don't overwrite a user's work outside of the scenario)" do
          agents(:bob_weather_agent).update_attribute :guid, "a-weather-agent"

          lambda {
            scenario_import.import
          }.should change { users(:bob).agents.count }.by(2)
        end
      end

      describe "#generate_diff" do
        it "returns AgentDiff objects for the incoming Agents" do
          scenario_import.should be_valid

          agent_diffs = scenario_import.agent_diffs

          weather_agent_diff = agent_diffs[0]
          trigger_agent_diff = agent_diffs[1]

          valid_parsed_weather_agent_data.each do |key, value|
            if key == :type
              value = value.split("::").last
            end
            weather_agent_diff.should respond_to(key)
            field = weather_agent_diff.send(key)
            field.should be_a(ScenarioImport::AgentDiff::FieldDiff)
            field.incoming.should == value
            field.updated.should == value
            field.current.should be_nil
          end
          weather_agent_diff.should_not respond_to(:propagate_immediately)

          valid_parsed_trigger_agent_data.each do |key, value|
            if key == :type
              value = value.split("::").last
            end
            trigger_agent_diff.should respond_to(key)
            field = trigger_agent_diff.send(key)
            field.should be_a(ScenarioImport::AgentDiff::FieldDiff)
            field.incoming.should == value
            field.updated.should == value
            field.current.should be_nil
          end
          trigger_agent_diff.should_not respond_to(:schedule)
        end
      end
    end

    context "when an a scenario already exists with the given guid" do
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
          lambda {
            scenario_import.import(:skip_agents => true)
            scenario_import.scenario.should == existing_scenario
          }.should_not change { users(:bob).scenarios.count }

          existing_scenario.reload
          existing_scenario.guid.should == guid
          existing_scenario.tag_fg_color.should == tag_fg_color
          existing_scenario.tag_bg_color.should == tag_bg_color
          existing_scenario.description.should == description
          existing_scenario.name.should == name
          existing_scenario.source_url.should == source_url
          existing_scenario.public.should be_falsey
        end

        it "updates any existing agents in the scenario, and makes new ones as needed" do
          scenario_import.should be_valid

          lambda {
            scenario_import.import
          }.should change { users(:bob).agents.count }.by(1) # One, because the weather agent already existed.

          weather_agent = existing_scenario.agents.find_by(:guid => "a-weather-agent")
          trigger_agent = existing_scenario.agents.find_by(:guid => "a-trigger-agent")

          weather_agent.should == agents(:bob_weather_agent)

          weather_agent.name.should == "a weather agent"
          weather_agent.schedule.should == "5pm"
          weather_agent.keep_events_for.should == 14
          weather_agent.propagate_immediately.should be_falsey
          weather_agent.should be_disabled
          weather_agent.memory.should be_empty
          weather_agent.options.should == weather_agent_options

          trigger_agent.name.should == "listen for weather"
          trigger_agent.sources.should == [weather_agent]
          trigger_agent.schedule.should be_nil
          trigger_agent.keep_events_for.should == 0
          trigger_agent.propagate_immediately.should be_truthy
          trigger_agent.should_not be_disabled
          trigger_agent.memory.should be_empty
          trigger_agent.options.should == trigger_agent_options
        end

        it "honors updates coming from the UI" do
          scenario_import.merges = {
            "0" => {
              "name" => "updated name",
              "schedule" => "6pm",
              "keep_events_for" => "2",
              "disabled" => "false",
              "options" => weather_agent_options.merge("api_key" => "foo").to_json
            }
          }

          scenario_import.should be_valid

          scenario_import.import.should be_truthy

          weather_agent = existing_scenario.agents.find_by(:guid => "a-weather-agent")
          weather_agent.name.should == "updated name"
          weather_agent.schedule.should == "6pm"
          weather_agent.keep_events_for.should == 2
          weather_agent.should_not be_disabled
          weather_agent.options.should == weather_agent_options.merge("api_key" => "foo")
        end

        it "adds errors when updated agents are invalid" do
          scenario_import.merges = {
            "0" => {
              "name" => "",
              "schedule" => "foo",
              "keep_events_for" => "2",
              "options" => weather_agent_options.merge("api_key" => "").to_json
            }
          }

          scenario_import.import.should be_falsey

          errors = scenario_import.errors.full_messages.to_sentence
          errors.should =~ /Name can't be blank/
          errors.should =~ /api_key is required/
          errors.should =~ /Schedule is not a valid schedule/
        end
      end

      describe "#generate_diff" do
        it "returns AgentDiff objects that include 'current' values from any agents that already exist" do
          agent_diffs = scenario_import.agent_diffs
          weather_agent_diff = agent_diffs[0]
          trigger_agent_diff = agent_diffs[1]

          # Already exists
          weather_agent_diff.agent.should == agents(:bob_weather_agent)
          valid_parsed_weather_agent_data.each do |key, value|
            next if key == :type
            weather_agent_diff.send(key).current.should == agents(:bob_weather_agent).send(key)
          end

          # Doesn't exist yet
          valid_parsed_trigger_agent_data.each do |key, value|
            trigger_agent_diff.send(key).current.should be_nil
          end
        end

        it "sets the 'updated' FieldDiff values based on any feedback from the user" do
          scenario_import.merges = {
            "0" => {
              "name" => "a new name",
              "schedule" => "6pm",
              "keep_events_for" => "2",
              "disabled" => "true",
              "options" => weather_agent_options.merge("api_key" => "foo").to_json
            },
            "1" => {
              "name" => "another new name"
            }
          }

          scenario_import.should be_valid

          agent_diffs = scenario_import.agent_diffs
          weather_agent_diff = agent_diffs[0]
          trigger_agent_diff = agent_diffs[1]

          weather_agent_diff.name.current.should == agents(:bob_weather_agent).name
          weather_agent_diff.name.incoming.should == valid_parsed_weather_agent_data[:name]
          weather_agent_diff.name.updated.should == "a new name"

          weather_agent_diff.schedule.updated.should == "6pm"
          weather_agent_diff.keep_events_for.updated.should == "2"
          weather_agent_diff.disabled.updated.should == "true"
          weather_agent_diff.options.updated.should == weather_agent_options.merge("api_key" => "foo")
        end

        it "adds errors on validation when updated options are unparsable" do
          scenario_import.merges = {
            "0" => {
              "options" => '{'
            }
          }
          scenario_import.should_not be_valid
          scenario_import.should have(1).error_on(:base)
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
          basecamp_agent_diff.requires_service?.should == true
        end

        it "should add an error when no service is selected" do
          services_scenario_import.import.should == false
          services_scenario_import.errors[:base].length.should == 1
        end
      end

      describe "#import" do
        it "should import" do
          services_scenario_import.merges = {
            "0" => {
              "service_id" => "0",
            }
          }
          lambda {
            services_scenario_import.import.should == true
          }.should change { users(:bob).agents.count }.by(2)
        end
      end
    end
  end
end
