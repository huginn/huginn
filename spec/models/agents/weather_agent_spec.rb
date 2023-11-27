require 'rails_helper'

describe Agents::WeatherAgent do
  let(:agent) do
    Agents::WeatherAgent.create(
      name: 'weather',
      options: {
          :location => "37.77550,-122.41292",
        :api_key => 'test',
        :which_day => 1,
      }
    ).tap do |agent|
      agent.user = users(:bob)
      agent.save!
    end
  end

  let :pirate_weather_agent do
    Agents::WeatherAgent.create(
      name: "weather from Pirate Weather",
      options: {
          :location => "37.779329,-122.41915",
          :service => "pirateweather",
          :which_day => 1,
          :api_key => "test"
      }
    ).tap do |agent|
      agent.user = users(:bob)
      agent.save!
    end
  end

  it "creates a valid agent" do
    expect(agent).to be_valid
  end

  it "is valid with put-your-key-here or your-key" do
    agent.options['api_key'] = 'put-your-key-here'
    expect(agent).to be_valid
    expect(agent.working?).to be_falsey

    agent.options['api_key'] = 'your-key'
    expect(agent).to be_valid
    expect(agent.working?).to be_falsey
  end

  context "pirate weather" do
    it "validates the location properly" do
      expect(pirate_weather_agent.options["location"]).to eq "37.779329,-122.41915"
      expect(pirate_weather_agent).to be_valid
      pirate_weather_agent.options["location"] = "37.779329, -122.41915" # with a space
      expect(pirate_weather_agent).to be_valid
      pirate_weather_agent.options["location"] = "94103" # a zip code
      expect(pirate_weather_agent).to_not be_valid
      pirate_weather_agent.options["location"] = "37.779329,-122.41915"
      expect(pirate_weather_agent.options["location"]).to eq "37.779329,-122.41915"
      expect(pirate_weather_agent).to be_valid
    end
    it "fails cases that pass the first test but are invalid" do
      pirate_weather_agent.options["location"] = "137.779329, -122.41915" # too high latitude
      expect(pirate_weather_agent).to_not be_valid
      pirate_weather_agent.options["location"] = "37.779329, -522.41915" # too low longitude
      expect(pirate_weather_agent).to_not be_valid
    end
  end

  describe "#service" do
    it "doesn't have a Service object attached" do
      expect(agent.service).to be_nil
    end
  end

  describe "Agents::WeatherAgent::VALID_COORDS_REGEX" do
    it "matches 37.779329,-122.41915" do
      expect(
        "37.779329,-122.41915" =~ Agents::WeatherAgent::VALID_COORDS_REGEX
      ).to be_truthy
    end
    it "matches a dozen random valid values" do
      valid_longitude_range = -180.0..180.0
      valid_latitude_range = -90.0..90.0
      12.times do
        expect(
          "#{rand valid_latitude_range},#{rand valid_longitude_range}" =~ Agents::WeatherAgent::VALID_COORDS_REGEX
        ).not_to be_nil
      end
    end
  end
end
