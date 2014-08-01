class DiagramsController < ApplicationController
  def show
    @agents = if params[:scenario_id].present?
                current_user.scenarios.find(params[:scenario_id]).agents.includes(:receivers)
              else
                current_user.agents.includes(:receivers)
              end
  end
end
