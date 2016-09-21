require 'capybara_helper'

describe "handling undefined agents" do
  before do
    login_as(users(:bob))
    agent = agents(:bob_website_agent)
    agent.update_attribute(:type, 'Agents::UndefinedAgent')
  end

  it 'renders the error page' do
    visit agents_path
    expect(page).to have_text("Error: Agent(s) are 'missing in action'")
    expect(page).to have_text('Undefined Agent')
  end

  it 'deletes all undefined agents' do
    visit agents_path
    click_on('Delete Missing Agents')
    expect(page).to have_text('Your Agents')
  end
end
