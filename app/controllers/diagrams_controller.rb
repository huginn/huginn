class DiagramsController < ApplicationController
  def show
    if params[:scenario_id].present?
      @scenario = current_user.scenarios.find(params[:scenario_id])
      agents = @scenario.agents
    else
      agents = current_user.agents
    end
    @disabled_agents = agents.inactive
    agents = agents.active if params[:exclude_disabled].present?
    @agents = agents.includes(:receivers)
  end
end
