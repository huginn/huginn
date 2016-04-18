require 'capybara_helper'

describe "Creating a new agent", js: true do
  before(:each) do
    login_as(users(:bob))
  end

  it "creates an agent" do
    visit "/"
    page.find("a", text: "Agents").trigger(:mouseover)
    click_on("New Agent")

    select2("Trigger Agent", from: "Type")
    fill_in(:agent_name, with: "Test Trigger Agent")
    click_on "Save"

    expect(page).to have_text("Test Trigger Agent")
  end

  it "creates an alert if a new agent with invalid json is submitted" do
    visit "/"
    page.find("a", text: "Agents").trigger(:mouseover)
    click_on("New Agent")

    select2("Trigger Agent", from: "Type")
    fill_in(:agent_name, with: "Test Trigger Agent")
    click_on("Toggle View")

    fill_in(:agent_options, with: '{
      "expected_receive_period_in_days": "2"
      "keep_event": "false"
    }')
    expect(get_alert_text_from { click_on "Save" }).to have_text("Sorry, there appears to be an error in your JSON input. Please fix it before continuing.")
  end

  context "displaying the correct information" do
    before(:each) do
      visit new_agent_path
    end
    it "shows all options for agents that can be scheduled, create and receive events" do
      select2("Website Agent", from: "Type")
      expect(page).not_to have_content('This type of Agent cannot create events.')
    end

    it "does not show the target select2 field when the agent can not create events" do
      select2("Growl Agent", from: "Type")
      expect(page).to have_content('This type of Agent cannot create events.')
    end
  end

  it "allows to click on on the agent name in select2 tags" do
    agent = agents(:bob_weather_agent)
    visit new_agent_path
    select2("Website Agent", from: "Type")
    select2("SF Weather", from: 'Sources')
    click_on "SF Weather"
    expect(page).to have_content "Editing your WeatherAgent"
  end
end
