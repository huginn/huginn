class EventsController < ApplicationController
  before_filter :load_event, :except => :index

  def index
    if params[:agent]
      @agent = current_user.agents.find(params[:agent])
      @events = @agent.events.page(params[:page])
    else
      @events = current_user.events.preload(:agent).page(params[:page])
    end

    respond_to do |format|
      format.html
      format.json { render json: @event }
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
    redirect_to :back, :notice => "Event re-emitted"
  end

  def destroy
    @event.destroy

    respond_to do |format|
      format.html { redirect_to events_path }
      format.json { head :no_content }
    end
  end

  private

  def load_event
    @event = current_user.events.find(params[:id])
  end
end
