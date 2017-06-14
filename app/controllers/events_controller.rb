class EventsController < ApplicationController
  before_action :load_event, except: :index

  def index
    if params[:agent_id]
      @agent = current_user.agents.find(params[:agent_id])
      @events = @agent.events.page(params[:page])
    else
      @events = current_user.events.preload(:agent).page(params[:page])
    end

    respond_to do |format|
      format.html
      format.json { render json: @events }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @event }
    end
  end

  def reemit
    @event.reemit!
    respond_to do |format|
      format.html { redirect_back event_path(@event), notice: 'Event re-emitted.' }
    end
  end

  def destroy
    @event.destroy

    respond_to do |format|
      format.html { redirect_back events_path, notice: 'Event deleted.' }
      format.json { head :no_content }
    end
  end

  private

  def load_event
    @event = current_user.events.find(params[:id])
  end
end
