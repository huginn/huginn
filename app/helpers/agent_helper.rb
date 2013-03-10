module AgentHelper
  def agent_show_view(agent)
    name = agent.short_type.underscore
    if File.exists?(Rails.root.join("app", "views", "agents", "agent_views", name, "_show.html.erb"))
      File.join("agents", "agent_views", name, "show")
    end
  end

  def agent_show_class(agent)
    agent.short_type.underscore.dasherize
  end
end