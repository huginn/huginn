class EventsController < ApplicationController
  before_action :load_event, except: :index

  def index
    if params[:user]
      if current_user.admin?
        @agent_user = User.find_by!(username: params[:user])
      else
        render(text: 'unauthorized', status: 403) and return
      end
    else
      @agent_user = current_user
    end

    if params[:agent_id]
      @agent = @agent_user.agents.find(params[:agent_id])
      @events = @agent.events.page(params[:page])
    else
      @events = @agent_user.events.preload(:agent).page(params[:page])
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

  # override default options
  # to allow admin
  def default_url_options
    opts = {}
    if @agent_user && current_user.admin? && current_user != @agent_user
      opts[:user] = @agent_user.username
    end
    opts.merge(super)
  end

  private

  def load_event
    if params[:user] && current_user.admin?
      @event = User.find_by!(username: params[:user]).events.find(params[:id])
    else
      @event = current_user.events.find(params[:id])
    end
  end
end
