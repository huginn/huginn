require 'capybara_helper'

describe "Toggling the visibility of an agent", js: true do
  it "hides them if they are disabled" do
    login_as(users(:bob))
    visit("/agents")

    expect {
      click_on("Show/Hide Disabled Agents")
    }.to change{ find_all(".table-striped tr").count }.by(-1)
  end

  it "shows them when they are hidden" do
    login_as(users(:bob))
    visit("/agents")
    click_on("Show/Hide Disabled Agents")

    expect {
      click_on("Show/Hide Disabled Agents")
    }.to change{ find_all(".table-striped tr").count }.by(1)
  end
end
