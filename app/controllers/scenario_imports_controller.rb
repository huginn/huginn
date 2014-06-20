class ScenarioImportsController < ApplicationController
  def new
    @scenario_import = ScenarioImport.new(:url => params[:url])
  end

  def create
    @scenario_import = ScenarioImport.new(params[:scenario_import])
    @scenario_import.set_user(current_user)

    if @scenario_import.will_request_local?(scenarios_url)
      render :text => 'Sorry, you cannot import a Scenario by URL from your own Huginn server.' and return
    end

    if @scenario_import.valid? && @scenario_import.should_import? && @scenario_import.import
      redirect_to @scenario_import.scenario, notice: "Import successful!"
    else
      render action: "new"
    end
  end
end