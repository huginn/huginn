require 'capybara_select2'

module FeatureHelpers
  include CapybaraSelect2
  include CapybaraSelect2::Helpers

  def select_agent_type(search)
    agent_name = search[/\A.*?Agent\b/] || search
    select2(agent_name, search:, from: "Type")

    # Wait for all parts of the Agent form to load:
    expect(page).to have_css("div.function_buttons") # Options editor
    expect(page).to have_css(".well.description > p") # Markdown description
  end
end
