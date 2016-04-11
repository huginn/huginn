require 'open-uri'
class DefaultScenarioImporter
  def self.import(user)
    return unless ENV['IMPORT_DEFAULT_SCENARIO_FOR_ALL_USERS'] == 'true'
    seed(user)
  end

  def self.seed(user)
    scenario_import = ScenarioImport.new()
    scenario_import.set_user(user)
    scenario_file = ENV['DEFAULT_SCENARIO_FILE'].presence || File.join(Rails.root, "data", "default_scenario.json")
    begin
      scenario_import.file = open(scenario_file)
      raise "Import failed" unless scenario_import.valid? && scenario_import.import
    ensure
      scenario_import.file.close
    end
    return true
  end
end
