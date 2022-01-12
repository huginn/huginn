require 'rails_helper'

describe DefaultScenarioImporter do
  let(:user) { users(:bob) }
  describe '.import' do
    it 'imports a set of agents to get the user going when they are first created' do
      expect(DefaultScenarioImporter).to receive(:seed).with(kind_of(User))
      allow(ENV).to receive(:[]) { nil }
      allow(ENV).to receive(:[]).with('IMPORT_DEFAULT_SCENARIO_FOR_ALL_USERS') { 'true' }
      DefaultScenarioImporter.import(user)
    end

    it 'can be turned off' do
      allow(DefaultScenarioImporter).to receive(:seed) { fail "seed should not have been called"}
      allow(ENV).to receive(:[]) { nil }
      allow(ENV).to receive(:[]).with('IMPORT_DEFAULT_SCENARIO_FOR_ALL_USERS') { 'false' }
      DefaultScenarioImporter.import(user)
    end

    it 'is turned off for existing instances of Huginn' do
      allow(DefaultScenarioImporter).to receive(:seed) { fail "seed should not have been called"}
      allow(ENV).to receive(:[]) { nil }
      allow(ENV).to receive(:[]).with('IMPORT_DEFAULT_SCENARIO_FOR_ALL_USERS') { nil }
      DefaultScenarioImporter.import(user)
    end

  end

  describe '.seed' do
    it 'imports a set of agents to get the user going when they are first created' do
      expect { DefaultScenarioImporter.seed(user) }.to change(user.agents, :count).by(7)
    end

    it 'respects an environment variable that specifies a path or URL to a different scenario' do
      allow(ENV).to receive(:[]) { nil }
      allow(ENV).to receive(:[]).with('DEFAULT_SCENARIO_FILE') { File.join(Rails.root, "spec", "fixtures", "test_default_scenario.json") }
      expect { DefaultScenarioImporter.seed(user) }.to change(user.agents, :count).by(3)
    end

    it 'can not be turned off' do
      allow(ENV).to receive(:[]) { nil }
      allow(ENV).to receive(:[]).with('IMPORT_DEFAULT_SCENARIO_FOR_ALL_USERS') { 'true' }
      expect { DefaultScenarioImporter.seed(user) }.to change(user.agents, :count).by(7)
    end
  end
end
