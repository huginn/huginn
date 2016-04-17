require 'capybara_helper'

describe "Creating a new agent", js: true do
  it "creates an agent" do
    login_as(users(:bob))
    visit "/"
    page.find("a", text: "Agents").trigger(:mouseover)
    click_on("New Agent")

    select2("Trigger Agent", from: "Type")
    fill_in(:agent_name, with: "Test Trigger Agent")
    click_on "Save"

    expect(page).to have_text("Test Trigger Agent")
  end
end
