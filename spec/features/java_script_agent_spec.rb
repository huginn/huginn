require 'rails_helper'

describe "JavaScriptAgent", js: true do
  before do
    login_as(users(:bob))
  end

  def set_ace_editor_value(code)
    expect(page).to have_css(".ace-editor")

    # Wait for buildAce to finish initializing the editor before setting a value.
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.1 until page.evaluate_script(
        "!!$('.ace-editor').data('ace-editor')"
      )
    end

    page.execute_script(<<~JS)
      $('.ace-editor').data('ace-editor').setValue(#{code.to_json}, 1);
    JS
  end

  it "creates a JavaScriptAgent with code in the ace editor" do
    visit new_agent_path
    select2("Java Script Agent", search: "Java Script Agent", from: "Type")
    expect(page).to have_no_css("form.agent-form.type-changing")
    expect(page).to have_css(".ace-editor")
    fill_in(:agent_name, with: "My JS Agent")

    # The ace editor should be in JavaScript mode
    ace_editor = page.find(".ace-editor")
    expect(ace_editor["data-mode"]).to eq("javascript")

    # Enter code via the ace editor
    code = 'Agent.check = function() { this.createEvent({ "message": "hello" }); };'
    set_ace_editor_value(code)

    click_on "Save"

    expect(page).to have_text("My JS Agent")
    agent = Agent.find_by(name: "My JS Agent")
    expect(agent).to be_a(Agents::JavaScriptAgent)
    expect(agent.options['code']).to eq(code)
    expect(agent.options['language']).to eq('JavaScript')
  end

  it "edits an existing JavaScriptAgent" do
    agent = Agents::JavaScriptAgent.create!(
      user: users(:bob),
      name: "Existing JS Agent",
      options: {
        code: 'Agent.check = function() {};',
        language: 'JavaScript',
      }
    )

    visit edit_agent_path(agent)

    expect(page).to have_css(".ace-editor")

    new_code = 'Agent.check = function() { this.log("updated"); };'
    set_ace_editor_value(new_code)

    click_on "Save"

    expect(page).to have_text("Existing JS Agent")
    agent.reload
    expect(agent.options['code']).to eq(new_code)
    expect(agent.options['language']).to eq('JavaScript')
  end
end
