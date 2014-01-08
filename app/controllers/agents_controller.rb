class AgentsController < ApplicationController
  def index
    @agents = current_user.agents.page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @agents }
    end
  end

  def handle_details_post
    @agent = current_user.agents.find(params[:id])
    if @agent.respond_to?(:handle_details_post)
      render :json => @agent.handle_details_post(params) || {}
    else
      @agent.error "#handle_details_post called on an instance of #{@agent.class} that does not define it."
      head 500
    end
  end

  def run
    agent = current_user.agents.find(params[:id])
    Agent.async_check(agent.id)
    if params[:return] == "show"
      redirect_to agent_path(agent), notice: "Agent run queued"
    else
      redirect_to agents_path, notice: "Agent run queued"
    end
  end

  def type_details
    agent = Agent.build_for_type(params[:type], current_user, {})
    render :json => {
        :can_be_scheduled => agent.can_be_scheduled?,
        :can_receive_events => agent.can_receive_events?,
        :can_create_events => agent.can_create_events?,
        :options => agent.default_options,
        :description_html => agent.html_description
    }
  end

  def event_descriptions
    html = current_user.agents.find(params[:ids].split(",")).group_by(&:type).map { |type, agents|
      agents.map(&:html_event_description).uniq.map { |desc|
        "<p><strong>#{type}</strong><br />" + desc + "</p>"
      }
    }.flatten.join()
    render :json => { :description_html => html }
  end

  def remove_events
    @agent = current_user.agents.find(params[:id])
    @agent.events.delete_all
    redirect_to agents_path, notice: "All events removed"
  end

  def propagate
    details = Agent.receive!
    redirect_to agents_path, notice: "Queued propagation calls for #{details[:event_count]} event(s) on #{details[:agent_count]} agent(s)"
  end

  def show
    @agent = current_user.agents.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render json: @agent }
    end
  end

  def new
    @agent = current_user.agents.build

    respond_to do |format|
      format.html
      format.json { render json: @agent }
    end
  end

  def edit
    @agent = current_user.agents.find(params[:id])
  end

  def diagram
    @agents = current_user.agents.includes(:receivers)
  end

  def create
    @agent = Agent.build_for_type(params[:agent].delete(:type),
                                  current_user,
                                  params[:agent])
    respond_to do |format|
      if @agent.save
        format.html { redirect_to agents_path, notice: 'Your Agent was successfully created.' }
        format.json { render json: @agent, status: :created, location: @agent }
      else
        format.html { render action: "new" }
        format.json { render json: @agent.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @agent = current_user.agents.find(params[:id])

    respond_to do |format|
      if @agent.update_attributes(params[:agent])
        format.html { redirect_to agents_path, notice: 'Your Agent was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @agent.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @agent = current_user.agents.find(params[:id])
    @agent.destroy

    respond_to do |format|
      format.html { redirect_to agents_path }
      format.json { head :no_content }
    end
  end
end
