require 'rails_helper'

RSpec.describe 'scenario URL imports' do
  let(:user) { users(:bob) }
  let(:valid_data) do
    {
      schema_version: 1,
      name: 'A useful Scenario',
      description: 'This is a cool Huginn Scenario that does something useful!',
      guid: 'somescenarioguid',
      source_url: 'http://example.com/scenarios/2/export.json',
      agents: [{
        type: 'Agents::WeatherAgent',
        name: 'a weather agent',
        schedule: '5pm',
        keep_events_for: 14.days,
        disabled: true,
        guid: 'a-weather-agent',
        options: {
          'api_key' => 'some-api-key',
          'location' => '42.3601,-71.0589'
        }
      }],
      links: [],
      control_links: []
    }.to_json
  end

  def build_import(url)
    ScenarioImport.new(url: url).tap { |scenario_import| scenario_import.set_user(user) }
  end

  before do
    allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])
  end

  it 'continues to import a valid public scenario URL' do
    stub_request(:get, 'http://example.com/scenarios/1/export.json').to_return(status: 200, body: valid_data)

    scenario_import = build_import('http://example.com/scenarios/1/export.json')

    expect(scenario_import).to be_valid
  end

  it 'rejects URLs that resolve to local addresses' do
    scenario_import = build_import('http://127.0.0.1/scenarios/1/export.json')

    expect(scenario_import).not_to be_valid
    expect(scenario_import.errors[:url]).to include('URL host resolves to a blocked address')
  end

  it 'rejects hostnames when any resolved address is local' do
    allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34', '10.0.0.1'])
    stub_request(:get, 'http://example.com/scenarios/1/export.json').to_return(status: 200, body: valid_data)

    scenario_import = build_import('http://example.com/scenarios/1/export.json')

    expect(scenario_import).not_to be_valid
    expect(scenario_import.errors[:url]).to include('URL host resolves to a blocked address')
    expect(a_request(:get, 'http://example.com/scenarios/1/export.json')).not_to have_been_made
  end

  it 'rejects redirects to local addresses' do
    stub_request(:get, 'http://example.com/scenarios/redirect.json').to_return(
      status: 302,
      headers: { 'Location' => 'http://127.0.0.1/scenarios/1/export.json' }
    )

    scenario_import = build_import('http://example.com/scenarios/redirect.json')

    expect(scenario_import).not_to be_valid
    expect(scenario_import.errors[:url]).to include('URL host resolves to a blocked address')
    expect(a_request(:get, 'http://127.0.0.1/scenarios/1/export.json')).not_to have_been_made
  end
end
