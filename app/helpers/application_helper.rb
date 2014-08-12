module ApplicationHelper
  def nav_link(name, path, options = {})
    content_tag :li, link_to(name, path), class: current_page?(path) ? 'active' : ''
  end

  def yes_no(bool)
    content_tag :span, bool ? 'Yes' : 'No', class: "label #{bool ? 'label-info' : 'label-default' }"
  end

  def working(agent)
    if agent.disabled?
      link_to 'Disabled', agent_path(agent), class: 'label label-warning'
    elsif agent.working?
      content_tag :span, 'Yes', class: 'label label-success'
    else
      link_to 'No', agent_path(agent, tab: (agent.recent_error_logs? ? 'logs' : 'details')), class: 'label label-danger'
    end
  end
end
