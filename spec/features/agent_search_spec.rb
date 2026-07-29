require "capybara_helper"

describe "Searching for an Agent", js: true do
  before do
    login_as(users(:bob))
  end

  it "shows Agent types and prioritizes name matches" do
    agents(:bob_weather_agent).dup.tap do |agent|
      agent.name = "Alpha"
      agent.guid = SecureRandom.hex
      agent.save!
    end

    visit root_path
    find("#agent-navigate").set("Weather")

    expect(page).to have_css(".tt-suggestion .agent-search-name", text: "Alpha")
    suggestions = page.all(".tt-suggestion")
    names = suggestions.map { |suggestion| suggestion.find(".agent-search-name").text }
    alpha_index = names.index("Alpha")
    name_match_indexes = names.each_index.select { |index| names[index].downcase.include?("weather") }

    expect(alpha_index).to be > name_match_indexes.max
    expect(suggestions[alpha_index]).to have_text("Weather Agent")
  end
end
