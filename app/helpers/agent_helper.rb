module AgentHelper

  def agent_show_view(agent)
    path = File.join('agents', 'agent_views', @agent.short_type.underscore, 'show')
    return self.controller.template_exists?(path, [], true) ? path : nil
  end

  def toggle_disabled_text
    if cookies[:huginn_view_only_enabled_agents]
      " Show Disabled Agents"
    else
      " Hide Disabled Agents"
    end
  end

  def scenario_links(agent)
    agent.scenarios.map { |scenario|
      link_to(scenario.name, scenario, class: "label", style: style_colors(scenario))
    }.join(" ").html_safe
  end

  def agent_show_class(agent)
    agent.short_type.underscore.dasherize
  end

  def agent_schedule(agent, delimiter = ', ')
    return 'n/a' unless agent.can_be_scheduled?

    case agent.schedule
    when nil, 'never'
      agent_controllers(agent, delimiter) || 'Never'
    else
      [
        builtin_schedule_name(agent.schedule),
        *(agent_controllers(agent, delimiter))
      ].join(delimiter).html_safe
    end
  end

  def builtin_schedule_name(schedule)
    AgentHelper.builtin_schedule_name(schedule)
  end

  def self.builtin_schedule_name(schedule)
    schedule == 'every_7d' ? 'Every Monday' : schedule.humanize.titleize
  end

  def agent_controllers(agent, delimiter = ', ')
    if agent.controllers.present?
      agent.controllers.map { |agent|
        link_to(agent.name, agent_path(agent))
      }.join(delimiter).html_safe
    end
  end

  def agent_dry_run_with_event_mode(agent)
    case
    when agent.cannot_receive_events?
      'no'.freeze
    when agent.cannot_be_scheduled?
      # incoming event is the only trigger for the agent
      'yes'.freeze
    else
      'maybe'.freeze
    end
  end

  def agent_type_icon(agent, agents)
    receiver_count = links_counter_cache(agents)[:links_as_receiver][agent.id] || 0
    control_count  = links_counter_cache(agents)[:control_links_as_controller][agent.id] || 0
    source_count   = links_counter_cache(agents)[:links_as_source][agent.id] || 0

    if control_count > 0 && receiver_count > 0
      content_tag('span') do
        concat icon_tag('glyphicon-arrow-right')
        concat tag('br')
        concat icon_tag('glyphicon-new-window', class: 'glyphicon-flipped')
      end
    elsif control_count > 0 && receiver_count == 0
      icon_tag('glyphicon-new-window', class: 'glyphicon-flipped')
    elsif receiver_count > 0 && source_count == 0
      icon_tag('glyphicon-arrow-right')
    elsif receiver_count == 0 && source_count > 0
      icon_tag('glyphicon-arrow-left')
    elsif receiver_count > 0 && source_count > 0
      icon_tag('glyphicon-transfer')
    else
      icon_tag('glyphicon-unchecked')
    end
  end

  def agent_type_select_options
    Rails.cache.fetch('agent_type_select_options') do
      [['Select an Agent Type', 'Agent', {title: ''}]] + Agent.types.map {|type| [agent_type_to_human(type.name), type, {title: h(Agent.build_for_type(type.name, User.new(id: 0), {}).html_description.lines.first.strip)}] }
    end
  end

  private

  def links_counter_cache(agents)
    @counter_cache ||= {}
    @counter_cache[agents.__id__] ||= {}.tap do |cache|
      agent_ids = agents.map(&:id)
      cache[:links_as_receiver] = Hash[Link.where(receiver_id: agent_ids)
                                           .group(:receiver_id)
                                           .pluck(:receiver_id, Arel.sql('count(receiver_id) as id'))]
      cache[:links_as_source]   = Hash[Link.where(source_id: agent_ids)
                                           .group(:source_id)
                                           .pluck(:source_id, Arel.sql('count(source_id) as id'))]
      cache[:control_links_as_controller] = Hash[ControlLink.where(controller_id: agent_ids)
                                                            .group(:controller_id)
                                                            .pluck(:controller_id, Arel.sql('count(controller_id) as id'))]
    end
  end
end
