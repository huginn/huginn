require 'capybara_helper'

describe "HTML safety", js: true do
  it "displays a shared service name as text on the agent page" do
    name = %q{Account <img src=x onerror="window.serviceNameExecuted=true">}
    service = services(:global)
    service.update!(provider: "twitter", name: name)
    agent = agents(:bob_twitter_user_agent)
    agent.update_column(:service_id, service.id)
    login_as(users(:bob))

    visit agent_path(agent)

    expect(page).to have_css('.label-service.service-twitter', text: "Twitter - #{name}")
    expect(page).to have_no_css('.label-service img')
    expect(page.evaluate_script('window.serviceNameExecuted')).to be_nil
  end

  it "sanitizes agent options interpolated into descriptions" do
    agent = users(:bob).agents.create!(
      type: "Agents::WebhookAgent", name: "Webhook",
      options: { secret: "value\n```\n\n<img src=x onerror='window.descriptionExecuted=true'>\n\n```" }
    )
    login_as(users(:bob))

    visit edit_agent_path(agent)

    expect(page).to have_text('The Webhook Agent will create events')
    expect(page).to have_no_css('.description [onerror]')
    expect(page.evaluate_script('window.descriptionExecuted')).to be_nil
  end
end
