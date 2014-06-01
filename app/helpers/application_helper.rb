module ApplicationHelper
  def nav_link(name, path, options = {})
    (<<-HTML).html_safe
      <li class='#{(current_page?(path) ? "active" : "")}'>
        #{link_to name, path}
      </li>
    HTML
  end

  def working(agent)
    if agent.disabled?
      link_to 'Disabled', agent_path(agent), :class => 'label label-warning'
    elsif agent.working?
      '<span class="label label-success">Yes</span>'.html_safe
    else
      link_to 'No', agent_path(agent, :tab => (agent.recent_error_logs? ? 'logs' : 'details')), :class => 'label label-danger'
    end
  end
end
