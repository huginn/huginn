load "spec/rails_helper.rb"
load File.join("db/migrate", "#{File.basename(__FILE__, "_spec.rb")}.rb")

describe DisconnectUnauthorizedAgentServices do
  it "disconnects and disables Agents using another user's private Service" do
    private_service = services(:global).dup
    private_service.update!(name: "Private service", global: false)
    unauthorized_agent = agents(:bob_website_agent)
    unauthorized_agent.update_columns(service_id: private_service.id, disabled: false)

    described_class.new.up

    expect(unauthorized_agent.reload).to have_attributes(service_id: nil, disabled: true)
  end

  it "preserves Agents using an owned or global Service" do
    owned_agent = agents(:bob_twitter_user_agent)
    global_agent = agents(:bob_weather_agent)
    global_agent.update_columns(service_id: services(:global).id, disabled: false)

    described_class.new.up

    expect(owned_agent.reload.service_id).to eq(services(:generic).id)
    expect(global_agent.reload).to have_attributes(service_id: services(:global).id, disabled: false)
  end
end
