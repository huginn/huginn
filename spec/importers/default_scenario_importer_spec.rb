require 'rails_helper'

describe DefaultScenarioImporter do
  let(:user) { users(:bob) }
  describe '.import' do
    it 'imports a set of agents to get the user going when they are first created' do
      mock(DefaultScenarioImporter).seed(is_a(User))
      stub.proxy(ENV).[](anything)
      stub(ENV).[]('IMPORT_DEFAULT_SCENARIO_FOR_ALL_USERS') { 'true' }
      DefaultScenarioImporter.import(user)
    end

    it 'can be turned off' do
      stub(DefaultScenarioImporter).seed { fail "seed should not have been called"}
      stub.proxy(ENV).[](anything)
      stub(ENV).[]('IMPORT_DEFAULT_SCENARIO_FOR_ALL_USERS') { 'false' }
      DefaultScenarioImporter.import(user)
    end

    it 'is turned off for existing instances of Huginn' do
      stub(DefaultScenarioImporter).seed { fail "seed should not have been called"}
      stub.proxy(ENV).[](anything)
      stub(ENV).[]('IMPORT_DEFAULT_SCENARIO_FOR_ALL_USERS') { nil }
      DefaultScenarioImporter.import(user)
    end

  end

  describe '.seed' do
    it 'imports a set of agents to get the user going when they are first created' do
      expect { DefaultScenarioImporter.seed(user) }.to change(user.agents, :count).by(7)
    end

    it 'respects an environment variable that specifies a path or URL to a different scenario' do
      stub.proxy(ENV).[](anything)
      stub(ENV).[]('DEFAULT_SCENARIO_FILE') { File.join(Rails.root, "spec", "fixtures", "test_default_scenario.json") }
      expect { DefaultScenarioImporter.seed(user) }.to change(user.agents, :count).by(3)
    end

    it 'can not be turned off' do
      stub.proxy(ENV).[](anything)
      stub(ENV).[]('IMPORT_DEFAULT_SCENARIO_FOR_ALL_USERS') { 'true' }
      expect { DefaultScenarioImporter.seed(user) }.to change(user.agents, :count).by(7)
    end
  end
end
