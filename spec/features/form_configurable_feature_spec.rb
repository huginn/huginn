require 'capybara_helper'

describe "form configuring agents", js: true do
  it 'completes fields with predefined array values' do
    login_as(users(:bob))
    visit edit_agent_path(agents(:bob_csv_agent))
    check('Propagate immediately')
    select2("serialize", from: "Mode", match: :first)
  end
end
