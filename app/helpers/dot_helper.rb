module DotHelper
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

  def disabled_label(agent)
    agent.disabled? ? dot_id(agent.name + " (Disabled)") : dot_id(agent.name)
  end

  def agents_dot(agents, rich = false)
    "digraph foo {".tap { |dot|
      agents.each.with_index do |agent, index|
        if rich
          dot << '%s[URL=%s];' % [disabled_label(agent), dot_id(agent_path(agent.id))]
        else
          dot << '%s;' % disabled_label(agent)
        end
        agent.receivers.each do |receiver|
          dot << "%s->%s;" % [disabled_label(agent), disabled_label(receiver)]
        end
      end
      dot << "}"
    }
  end
end
