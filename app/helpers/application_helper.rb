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

  def render_dot(dot_format_string)
    if (command = ENV['USE_GRAPHVIZ_DOT']) &&
       (svg = IO.popen([command, *%w[-Tsvg -q1 -o/dev/stdout /dev/stdin]], 'w+') { |dot|
          dot.print dot_format_string
          dot.close_write
          dot.read
        } rescue false)
      svg.html_safe
    else
      tag('img', src: URI('https://chart.googleapis.com/chart').tap { |uri|
            uri.query = URI.encode_www_form(cht: 'gv', chl: dot_format_string)
          })
    end
  end
end
