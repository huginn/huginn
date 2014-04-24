module ApplicationHelper
  def nav_link(name, path, options = {})
    (<<-HTML).html_safe
      <li class='#{(current_page?(path) ? "active" : "")}'>
        #{link_to name, path}
      </li>
    HTML
  end

  def working(agent)
    if agent.working?
      '<span class="label label-success">Yes</span>'.html_safe
    else
      link_to '<span class="label label-warning">No</span>'.html_safe, agent_path(agent, :tab => (agent.recent_error_logs? ? 'logs' : 'details'))
    end
  end
end
