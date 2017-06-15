module Users
  class RegistrationsController < Devise::RegistrationsController
    after_action :create_default_scenario, only: :create

    private

    def create_default_scenario
      DefaultScenarioImporter.import(@user) if @user.persisted?
    end
  end
end
