module FeatureHelpers
  def select_agent_type(search)
    agent_name = search[/\A.*?Agent\b/] || search
    select2(agent_name, search:, from: "Type")

    expect(page).to have_no_css("form.agent-form.type-changing")

    # Wait for all parts of the Agent form to load:
    expect(page).to have_css(".json-editor-shell") # Options editor
    expect(page).to have_css(".well.description > p") # Markdown description
  end
end
