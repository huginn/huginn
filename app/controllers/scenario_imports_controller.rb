class ScenarioImportsController < ApplicationController
  def new
    @scenario_import = ScenarioImport.new(:url => params[:url])
  end

  def create
    @scenario_import = ScenarioImport.new(params[:scenario_import])
    @scenario_import.set_user(current_user)

    if @scenario_import.valid? && @scenario_import.import_confirmed? && @scenario_import.import
      redirect_to @scenario_import.scenario, notice: "Import successful!"
    else
      render action: "new"
    end
  end
end