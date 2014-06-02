class ScenarioImportsController < ApplicationController
  def new
    @scenario_import = ScenarioImport.new
  end

  def create
    @scenario_import = ScenarioImport.new(params[:scenario_import])
    @scenario_import.set_user(current_user)

    if @scenario_import.valid?
      if @scenario_import.do_import?
        @scenario_import.import!
        redirect_to @scenario_import.scenario, notice: "Import successful!"
      else
        render action: "new"
      end
    else
      render action: "new"
    end
  end
end