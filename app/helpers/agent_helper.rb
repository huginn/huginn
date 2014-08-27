module AgentHelper
  def agent_show_view(agent)
    name = agent.short_type.underscore
    if File.exists?(Rails.root.join("app", "views", "agents", "agent_views", name, "_show.html.erb"))
      File.join("agents", "agent_views", name, "show")
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

    controllers = agent.controllers
    [
      *(CGI.escape_html(agent.schedule.humanize.titleize) unless agent.schedule == 'never' && agent.controllers.count > 0),
      *controllers.map { |agent| link_to(agent.name, agent_path(agent)) },
    ].join(delimiter).html_safe
  end
end
