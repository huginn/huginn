# Encapsulates the logic for editing/creating an agent.
class AgentForm
  extend Forwardable

  # agent --- The agent to edit.
  # user  --- The user doing the editing.
  # view  --- The view context for generating the form.
  def initialize(agent:, user: agent.user, view:)
    @agent = agent
    @user = user
    @view = view
    if @agent.try(:is_form_configurable?)
      @agent = FormConfigurableAgentPresenter.new(agent, view)
    end
  end

  attr_reader :agent
  def_delegators :agent, :errors, :keep_events_for, :new_record?, :short_type
  def_delegator :user, :scenarios?
  alias_method :changeable_type?, :new_record?

  def agent_type_select
    AgentTypeSelector.new(select_id: :type, selected: agent.type, user: user, view: view)
  end

  def attrs
    {
      as: :agent,
      html: {class: 'agent-form'},
      method: method,
      url: url,
    }
  end

  def controllers?
    !agent.controllers.empty?
  end

  def controls_others?
    agent.can_control_other_agents?
  end

  def control_targets_select
    Select2Selector.new(agent_params(select_id: :control_target_ids, selected: agent.control_target_ids))
  end

  def creates_events?
    agent.can_create_events?
  end

  def error_messages
    errors.full_messages
  end

  def errors?
    errors.any?
  end

  def event_sources_select
    Select2Selector.new(agent_params(filter: :can_create_events?, select_id: :source_ids, selected: agent.source_ids))
  end

  def event_targets_select
    Select2Selector.new(agent_params(filter: :can_receive_events?, select_id: :receiver_ids, selected: agent.receiver_ids))
  end

  def html_description
    agent.try(:html_description)
  end

  def keep_events_select
    Selector.new(data: retention_schedules, selected: agent.keep_events_for, select_id: :keep_events_for, view: view)
  end

  def links
    @links ||= {
      back: view.agents_path,
      show: view.agent_path(agent)
    }
  end

  def number_of_errors
    errors.count
  end

  def receives_events?
    agent.can_receive_events?
  end

  def schedulable?
    agent.can_be_scheduled?
  end

  def scenarios_select
    Select2Selector.new(data: user.scenarios, select_id: :scenario_ids, selected: agent.scenario_ids, url_prefix: '/scenarios', view: view)
  end

  def schedule_select
    ScheduleSelector.new(select_id: :schedule, selected: agent.schedule, view: view)
  end

  private

  attr_reader :user
  attr_reader :view

  def agent_params(params)
    {data: other_agents, url_prefix: '/agents', view: view}.merge(params)
  end

  def method
    if new_record?
      'POST'
    else
      'PUT'
    end
  end

  def other_agents
    @other_agents ||= user.agents.where.not(id: agent.id)
  end

  def retention_schedules
    Agent::EVENT_RETENTION_SCHEDULES.map { |name, time|
      Selector::Container.new(name, time)
    }
  end

  def url
    if new_record?
      view.agents_path
    else
      view.agent_path(agent)
    end
  end
end
