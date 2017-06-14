require 'rails_helper'

describe "Editing an agent", js: true do
  it "creates an alert if a agent with invalid json is submitted" do
    login_as(users(:bob))
    visit("/agents/#{agents(:bob_website_agent).id}/edit")
    click_on("Toggle View")

    fill_in(:agent_options, with: '{
      "expected_receive_period_in_days": "2"
      "keep_event": "false"
    }')
    expect(get_alert_text_from { click_on "Save" }).to have_text("Sorry, there appears to be an error in your JSON input. Please fix it before continuing.")
  end
end
