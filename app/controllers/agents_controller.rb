class AgentsController < ApplicationController
  include DotHelper
  include ActionView::Helpers::TextHelper
  include SortableTable

  before_action :set_current_agents, :only => [:index, :handle_details_post, :run, :event_descriptions, :remove_events, :destroy_memory, :show, :new, :edit, :create, :update, :destroy, :validate, :complete]

  def index
    set_table_sort sorts: %w[name created_at last_check_at last_event_at last_receive_at], default: { created_at: :desc }

    @agents = @current_agents.preload(:scenarios, :controllers).reorder(table_sort).page(params[:page])

    if show_only_enabled_agents?
      @agents = @agents.where(disabled: false)
    end

    respond_to do |format|
      format.html
      format.json { render json: @agents }
    end
  end

  def toggle_visibility
    if show_only_enabled_agents?
      mark_all_agents_viewable
    else
      set_only_enabled_agents_as_viewable
    end

    redirect_to agents_path
  end

  def handle_details_post
    
    @agent = @current_agents.find(params[:id])
    if @agent.respond_to?(:handle_details_post)
      render :json => @agent.handle_details_post(params) || {}
    else
      @agent.error "#handle_details_post called on an instance of #{@agent.class} that does not define it."
      head 500
    end
  end

  def run
    
    @agent = @current_agents.find(params[:id])
    Agent.async_check(@agent.id)

    respond_to do |format|
      format.html { redirect_back "Agent run queued for '#{@agent.name}'" }
      format.json { head :ok }
    end
  end

  def type_details
    @agent = Agent.build_for_type(params[:type], current_user, {})
    initialize_presenter

    render json: {
        can_be_scheduled: @agent.can_be_scheduled?,
        default_schedule: @agent.default_schedule,
        can_receive_events: @agent.can_receive_events?,
        can_create_events: @agent.can_create_events?,
        can_control_other_agents: @agent.can_control_other_agents?,
        can_dry_run: @agent.can_dry_run?,
        options: @agent.default_options,
        description_html: @agent.html_description,
        oauthable: render_to_string(partial: 'oauth_dropdown', locals: { agent: @agent }),
        form_options: render_to_string(partial: 'options', locals: { agent: @agent })
    }
  end

  def event_descriptions
    
    html = @current_agents.find(params[:ids].split(",")).group_by(&:type).map { |type, agents|
      agents.map(&:html_event_description).uniq.map { |desc|
        "<p><strong>#{type}</strong><br />" + desc + "</p>"
      }
    }.flatten.join()
    render :json => { :description_html => html }
  end

  def remove_events
    
    @agent = @current_agents.find(params[:id])
    @agent.events.delete_all

    respond_to do |format|
      format.html { redirect_back "All emitted events removed for '#{@agent.name}'" }
      format.json { head :ok }
    end
  end

  def propagate
    respond_to do |format|
      if AgentPropagateJob.can_enqueue?
        details = Agent.receive! # Eventually this should probably be scoped to the current_user.
        format.html { redirect_back "Queued propagation calls for #{details[:event_count]} event(s) on #{details[:agent_count]} agent(s)" }
        format.json { head :ok }
      else
        format.html { redirect_back "Event propagation is already scheduled to run." }
        format.json { head :locked }
      end
    end
  end

  def destroy_memory
    
    @agent = @current_agents.find(params[:id])
    @agent.update!(memory: {})

    respond_to do |format|
      format.html { redirect_back "Memory erased for '#{@agent.name}'" }
      format.json { head :ok }
    end
  end

  def show
    
    @agent = @current_agents.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render json: @agent }
    end
  end

  def new
    
    agents = @current_agents

    if id = params[:id]
      @agent = agents.build_clone(agents.find(id))
    else
      @agent = agents.build
    end

    @agent.scenario_ids = [params[:scenario_id]] if params[:scenario_id] && current_user.scenarios.find_by(id: params[:scenario_id])

    initialize_presenter

    respond_to do |format|
      format.html
      format.json { render json: @agent }
    end
  end

  def edit
    @agent = @current_agents.find(params[:id])
    initialize_presenter
  end

  def create
    build_agent

    respond_to do |format|
      if @agent.save
        format.html { redirect_back "'#{@agent.name}' was successfully created.", return: agents_path }
        format.json { render json: @agent, status: :ok, location: agent_path(@agent) }
      else
        initialize_presenter
        format.html { render action: "new" }
        format.json { render json: @agent.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    
    @agent = @current_agents.find(params[:id])

    respond_to do |format|
      if @agent.update_attributes(params[:agent])
        format.html { redirect_back "'#{@agent.name}' was successfully updated.", return: agents_path }
        format.json { render json: @agent, status: :ok, location: agent_path(@agent) }
      else
        initialize_presenter
        format.html { render action: "edit" }
        format.json { render json: @agent.errors, status: :unprocessable_entity }
      end
    end
  end

  def leave_scenario
    @current_agents = current_user.agents
    @agent = @current_agents.find(params[:id])
    @scenario = current_user.scenarios.find(params[:scenario_id])
    @agent.scenarios.destroy(@scenario)

    respond_to do |format|
      format.html { redirect_back "'#{@agent.name}' removed from '#{@scenario.name}'" }
      format.json { head :no_content }
    end
  end

  def destroy
    
    @agent = @current_agents.find(params[:id])
    @agent.destroy

    respond_to do |format|
      format.html { redirect_back "'#{@agent.name}' deleted" }
      format.json { head :no_content }
    end
  end

  def validate
    build_agent

    if @agent.validate_option(params[:attribute])
      render text: 'ok'
    else
      render text: 'error', status: 403
    end
  end

  def complete
    build_agent

    render json: @agent.complete_option(params[:attribute])
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

  protected

  # Sanitize params[:return] to prevent open redirect attacks, a common security issue.
  def redirect_back(message, options = {})
    if path = filtered_agent_return_link(options)
      redirect_to path, notice: message
    else
      super agents_path, notice: message
    end
  end

  def build_agent
    @agent = Agent.build_for_type(params[:agent].delete(:type),
                                  @agent_user,
                                  params[:agent])
  end

  def initialize_presenter
    if @agent.present? && @agent.is_form_configurable?
      @agent = FormConfigurableAgentPresenter.new(@agent, view_context)
    end
  end

  private
  def set_current_agents
    if params[:user]
      if current_user.admin?
        @agent_user = User.find_by!(username: params[:user])
      else
        render(text: 'unauthorized', status: 403) and return
      end
    else
      @agent_user = current_user
    end
    @current_agents = @agent_user.agents
  end

  def show_only_enabled_agents?
    !!cookies[:huginn_view_only_enabled_agents]
  end

  def set_only_enabled_agents_as_viewable
    cookies[:huginn_view_only_enabled_agents] = {
      value: "true",
      expires: 1.year.from_now
    }
  end

  def mark_all_agents_viewable
    cookies.delete(:huginn_view_only_enabled_agents)
  end
end
