require 'capybara_helper'

describe "Agent filters", js: true do
  it "shows account buttons and preserves combined filters across navigation" do
    service = services(:generic)
    service.update!(provider: "github", name: "example-account")
    login_as(users(:bob))
    visit agents_path(sort: "name.asc")

    find("#select2-agent_service_filter-container").click
    find(".select2-results__option[role=option]", text: "example-account").click
    expect(page).to have_current_path(/service_id=#{service.id}/)
    expect(page).to have_css("#select2-agent_service_filter-container .fa-github")
    expect(find("#select2-agent_service_filter-container")).to have_text("example-account")
    expect(find("#select2-agent_service_filter-container")).not_to have_text("GitHub")
    expect(page).to have_text(agents(:bob_twitter_user_agent).name)

    find("#select2-agent_scenario_filter-container").click
    expect(page).to have_css(".select2-results__group", text: "Scenarios")
    find(".select2-results__option[role=option]", text: "No scenario").click
    expect(page).to have_current_path(/without_scenario=1/)
    expect(page).to have_current_path(/sort=name.asc/)
    expect(page).to have_current_path(/service_id=#{service.id}/)
    check "Enabled only"
    expect(page).to have_checked_field("Enabled only")
    expect(page).to have_current_path(/without_scenario=1/)

    page.driver.browser.manage.window.resize_to(1280, 900)
    expect(page.evaluate_script('getComputedStyle(document.querySelector(".agents-index-layout")).display')).to eq("grid")
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 800, deviceScaleFactor: 1, mobile: false)
    expect(page.evaluate_script('innerWidth')).to eq(375)
    expect(page.evaluate_script('getComputedStyle(document.querySelector(".agents-index-layout")).display')).to eq("block")
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
  end
end
