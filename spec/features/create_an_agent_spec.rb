require 'rails_helper'

describe "Creating a new agent", js: true do
  before(:each) do
    login_as(users(:bob))
  end

  it "creates an agent" do
    visit "/"
    page.find("a", text: "Agents").trigger(:mouseover)
    click_on("New Agent")

    select_agent_type("Trigger Agent")
    fill_in(:agent_name, with: "Test Trigger Agent")
    click_on "Save"

    expect(page).to have_text("Test Trigger Agent")
  end

  it "creates an alert if a new agent with invalid json is submitted" do
    visit "/"
    page.find("a", text: "Agents").trigger(:mouseover)
    click_on("New Agent")

    select_agent_type("Trigger Agent")
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
      select_agent_type("Website Agent scrapes")
      expect(page).not_to have_content('This type of Agent cannot create events.')
    end

    it "does not show the target select2 field when the agent can not create events" do
      select_agent_type("Growl Agent")
      expect(page).to have_content('This type of Agent cannot create events.')
    end
  end

  it "allows to click on on the agent name in select2 tags" do
    visit new_agent_path
    select_agent_type("Website Agent scrapes")
    select2("SF Weather", from: 'Sources')
    click_on "SF Weather"
    expect(page).to have_content "Editing your WeatherAgent"
  end

  context "clearing unsupported fields of agents" do
    before do
      visit new_agent_path
    end

    it "does not send previously configured sources when the current agent does not support them" do
      select_agent_type("Website Agent scrapes")
      select2("SF Weather", from: 'Sources')
      select_agent_type("Webhook Agent")
      fill_in(:agent_name, with: "No sources")
      click_on "Save"
      expect(page).to have_content("No sources")
      agent = Agent.find_by(name: "No sources")
      expect(agent.sources).to eq([])
    end

    it "does not send previously configured control targets when the current agent does not support them" do
      select_agent_type("Commander Agent")
      select2("SF Weather", from: 'Control targets')
      select_agent_type("Webhook Agent")
      fill_in(:agent_name, with: "No control targets")
      click_on "Save"
      expect(page).to have_content("No control targets")
      agent = Agent.find_by(name: "No control targets")
      expect(agent.control_targets).to eq([])
    end

    it "does not send previously configured receivers when the current agent does not support them" do
      select_agent_type("Website Agent scrapes")
      sleep 0.5
      select2("ZKCD", from: 'Receivers')
      select_agent_type("Email Agent")
      fill_in(:agent_name, with: "No receivers")
      click_on "Save"
      expect(page).to have_content("No receivers")
      agent = Agent.find_by(name: "No receivers")
      expect(agent.receivers).to eq([])
    end
  end
end
