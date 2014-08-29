class AgentsController < ApplicationController
  include DotHelper

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
    @agent = current_user.agents.find(params[:id])
    Agent.async_check(@agent.id)

    respond_to do |format|
      format.html { redirect_back "Agent run queued for '#{@agent.name}'" }
      format.json { head :ok }
    end
  end

  def type_details
    @agent = Agent.build_for_type(params[:type], current_user, {})
    render :json => {
        :can_be_scheduled => @agent.can_be_scheduled?,
        :default_schedule => @agent.default_schedule,
        :can_receive_events => @agent.can_receive_events?,
        :can_create_events => @agent.can_create_events?,
        :options => @agent.default_options,
        :description_html => @agent.html_description,
        :form => render_to_string(partial: 'oauth_dropdown')
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

    respond_to do |format|
      format.html { redirect_back "All emitted events removed for '#{@agent.name}'" }
      format.json { head :ok }
    end
  end

  def propagate
    details = Agent.receive! # Eventually this should probably be scoped to the current_user.

    respond_to do |format|
      format.html { redirect_back "Queued propagation calls for #{details[:event_count]} event(s) on #{details[:agent_count]} agent(s)" }
      format.json { head :ok }
    end
  end

  def show
    @agent = current_user.agents.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render json: @agent }
    end
  end

  def new
    agents = current_user.agents

    if id = params[:id]
      @agent = agents.build_clone(agents.find(id))
    else
      @agent = agents.build
    end

    respond_to do |format|
      format.html
      format.json { render json: @agent }
    end
  end

  def edit
    @agent = current_user.agents.find(params[:id])
  end

  def create
    @agent = Agent.build_for_type(params[:agent].delete(:type),
                                  current_user,
                                  params[:agent])
    respond_to do |format|
      if @agent.save
        format.html { redirect_back "'#{@agent.name}' was successfully created." }
        format.json { render json: @agent, status: :ok, location: agent_path(@agent) }
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
        format.html { redirect_back "'#{@agent.name}' was successfully updated." }
        format.json { render json: @agent, status: :ok, location: agent_path(@agent) }
      else
        format.html { render action: "edit" }
        format.json { render json: @agent.errors, status: :unprocessable_entity }
      end
    end
  end

  def leave_scenario
    @agent = current_user.agents.find(params[:id])
    @scenario = current_user.scenarios.find(params[:scenario_id])
    @agent.scenarios.destroy(@scenario)

    respond_to do |format|
      format.html { redirect_back "'#{@agent.name}' removed from '#{@scenario.name}'" }
      format.json { head :no_content }
    end
  end

  def destroy
    @agent = current_user.agents.find(params[:id])
    @agent.destroy

    respond_to do |format|
      format.html { redirect_back "'#{@agent.name}' deleted" }
      format.json { head :no_content }
    end
  end

  protected

  # Sanitize params[:return] to prevent open redirect attacks, a common security issue.
  def redirect_back(message)
    if params[:return] == "show" && @agent
      path = agent_path(@agent)
    elsif params[:return] =~ /\A#{Regexp::escape scenarios_path}\/\d+\Z/
      path = params[:return]
    else
      path = agents_path
    end

    redirect_to path, notice: message
  end
end
