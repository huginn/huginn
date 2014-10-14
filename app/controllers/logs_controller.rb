class LogsController < ApplicationController
  before_action :load_agent

  def index
    @logs = @agent.logs.all
    render :action => :index, :layout => false
  end

  def clear
    @agent.delete_logs!
    index
  end

  protected

  def load_agent
    @agent = current_user.agents.find(params[:agent_id])
  end
end
