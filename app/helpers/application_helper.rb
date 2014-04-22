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

  def render_agents_diagram(agents)
    if (command = ENV['USE_GRAPHVIZ_DOT']) &&
       (svg = IO.popen([command, *%w[-Tsvg -q1 -o/dev/stdout /dev/stdin]], 'w+') { |dot|
          dot.print agents_dot(agents, true)
          dot.close_write
          dot.read
        } rescue false)
      svg.html_safe
    else
      tag('img', src: URI('https://chart.googleapis.com/chart').tap { |uri|
            uri.query = URI.encode_www_form(cht: 'gv', chl: agents_dot(agents))
          })
    end
  end

  private

  def dot_id(string)
    # Backslash escaping seems to work for the backslash itself,
    # despite the DOT language document.
    '"%s"' % string.gsub(/\\/, "\\\\\\\\").gsub(/"/, "\\\\\"")
  end

  def agents_dot(agents, rich = false)
    "digraph foo {".tap { |dot|
      agents.each.with_index do |agent, index|
        if rich
          dot << '%s[URL=%s];' % [dot_id(agent.name), dot_id(agent_path(agent.id))]
        else
          dot << '%s;' % dot_id(agent.name)
        end
        agent.receivers.each do |receiver|
          dot << "%s->%s;" % [dot_id(agent.name), dot_id(receiver.name)]
        end
      end
      dot << "}"
    }
  end
end
