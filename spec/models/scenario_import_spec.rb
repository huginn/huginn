require 'spec_helper'

describe ScenarioImport do
  let(:guid) { "somescenarioguid" }
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
  let(:valid_parsed_data) do
    { 
      :name => name,
      :description => description,
      :guid => guid,
      :source_url => source_url,
      :exported_at => 2.days.ago.utc.iso8601,
      :agents => [
        {
          :type => "Agents::WeatherAgent",
          :name => "a weather agent",
          :schedule => "5pm",
          :keep_events_for => 14,
          :propagate_immediately => false,
          :disabled => false,
          :guid => "a-weather-agent",
          :options => weather_agent_options
        },
        {
          :type => "Agents::TriggerAgent",
          :name => "listen for weather",
          :schedule => nil,
          :keep_events_for => 0,
          :propagate_immediately => true,
          :disabled => true,
          :guid => "a-trigger-agent",
          :options => trigger_agent_options
        }
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
    subject { ScenarioImport.new }

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

  describe "#import!" do
    let(:scenario_import) do
      _import = ScenarioImport.new(:data => valid_data)
      _import.set_user users(:bob)
      _import
    end

    context "when this scenario has never been seen before" do
      it "makes a new scenario" do
        lambda {
          scenario_import.import!(:skip_agents => true)
        }.should change { users(:bob).scenarios.count }.by(1)

        scenario_import.scenario.name.should == name
        scenario_import.scenario.description.should == description
        scenario_import.scenario.guid.should == guid
        scenario_import.scenario.source_url.should == source_url
        scenario_import.scenario.public.should be_false
      end

      it "creates the Agents" do
        lambda {
          scenario_import.import!
        }.should change { users(:bob).agents.count }.by(2)

        weather_agent = scenario_import.scenario.agents.find_by(:guid => "a-weather-agent")
        trigger_agent = scenario_import.scenario.agents.find_by(:guid => "a-trigger-agent")

        weather_agent.name.should == "a weather agent"
        weather_agent.schedule.should == "5pm"
        weather_agent.keep_events_for.should == 14
        weather_agent.propagate_immediately.should be_false
        weather_agent.should_not be_disabled
        weather_agent.memory.should be_empty
        weather_agent.options.should == weather_agent_options

        trigger_agent.name.should == "listen for weather"
        trigger_agent.sources.should == [weather_agent]
        trigger_agent.schedule.should be_nil
        trigger_agent.keep_events_for.should == 0
        trigger_agent.propagate_immediately.should be_true
        trigger_agent.should be_disabled
        trigger_agent.memory.should be_empty
        trigger_agent.options.should == trigger_agent_options
      end

      it "creates new Agents, even if one already exists with the given guid (so that we don't overwrite a user's work outside of the scenario)" do
        agents(:bob_weather_agent).update_attribute :guid, "a-weather-agent"

        lambda {
          scenario_import.import!
        }.should change { users(:bob).agents.count }.by(2)
      end
    end

    context "when an a scenario already exists with the given guid" do
      let!(:existing_scenario) {
        _existing_scenerio = users(:bob).scenarios.build(:name => "an existing scenario")
        _existing_scenerio.guid = guid
        _existing_scenerio.save!
        _existing_scenerio
      }

      it "uses the existing scenario, updating it's data" do
        lambda {
          scenario_import.import!(:skip_agents => true)
          scenario_import.scenario.should == existing_scenario
        }.should_not change { users(:bob).scenarios.count }

        existing_scenario.reload
        existing_scenario.guid.should == guid
        existing_scenario.description.should == description
        existing_scenario.name.should == name
        existing_scenario.source_url.should == source_url
        existing_scenario.public.should be_false
      end

      it "updates any existing agents in the scenario, and makes new ones as needed" do
        agents(:bob_weather_agent).update_attribute :guid, "a-weather-agent"
        agents(:bob_weather_agent).scenarios << existing_scenario

        lambda {
          # Shouldn't matter how many times we do it!
          scenario_import.import!
          scenario_import.import!
          scenario_import.import!
        }.should change { users(:bob).agents.count }.by(1)

        weather_agent = existing_scenario.agents.find_by(:guid => "a-weather-agent")
        trigger_agent = existing_scenario.agents.find_by(:guid => "a-trigger-agent")

        weather_agent.should == agents(:bob_weather_agent)

        weather_agent.name.should == "a weather agent"
        weather_agent.schedule.should == "5pm"
        weather_agent.keep_events_for.should == 14
        weather_agent.propagate_immediately.should be_false
        weather_agent.should_not be_disabled
        weather_agent.memory.should be_empty
        weather_agent.options.should == weather_agent_options

        trigger_agent.name.should == "listen for weather"
        trigger_agent.sources.should == [weather_agent]
        trigger_agent.schedule.should be_nil
        trigger_agent.keep_events_for.should == 0
        trigger_agent.propagate_immediately.should be_true
        trigger_agent.should be_disabled
        trigger_agent.memory.should be_empty
        trigger_agent.options.should == trigger_agent_options
      end
    end
  end
end