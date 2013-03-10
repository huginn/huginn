class EventsController < ApplicationController
  def index
    if params[:agent]
      @agent = current_user.agents.find(params[:agent])
      @events = @agent.events.page(params[:page])
    else
      @events = current_user.events.page(params[:page])
    end

    respond_to do |format|
      format.html
      format.json { render json: @event }
    end
  end

  def show
    @event = current_user.events.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render json: @event }
    end
  end

  def destroy
    event = current_user.events.find(params[:id])
    event.destroy

    respond_to do |format|
      format.html { redirect_to events_path }
      format.json { head :no_content }
    end
  end
end
