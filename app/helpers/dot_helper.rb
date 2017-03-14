module DotHelper
  def render_agents_diagram(agents, layout: nil)
    if (command = ENV['USE_GRAPHVIZ_DOT']) &&
       (svg = IO.popen([command, *%w[-Tsvg -q1 -o/dev/stdout /dev/stdin]], 'w+') { |dot|
          dot.print agents_dot(agents, rich: true, layout: layout)
          dot.close_write
          dot.read
        } rescue false)
      decorate_svg(svg, agents).html_safe
    else
      # Google chart request url 
      faraday = Faraday.new { |builder|
        builder.request :url_encoded
        builder.adapter Faraday.default_adapter
      }
      response = faraday.post('https://chart.googleapis.com/chart', { cht: 'gv', chl: agents_dot(agents) })

      case response.status
      when 200
        # Display Base64-Encoded images
        tag('img', src: 'data:image/jpg;base64,'+Base64.encode64(response.body))
      when 400
        "The diagram can't be displayed because it has too many nodes. Max allowed is 80."
      when 413
        "The diagram can't be displayed because it is too large."
      else
        "Unknow error. Response code is #{response.status}."
      end
    end
  end

  class DotDrawer
    def initialize(vars = {})
      @dot = ''
      @vars = vars.symbolize_keys
    end

    def method_missing(var, *args)
      @vars.fetch(var) { super }
    end

    def to_s
      @dot
    end

    def self.draw(*args, &block)
      drawer = new(*args)
      drawer.instance_exec(&block)
      drawer.to_s
    end

    def raw(string)
      @dot << string
    end

    ENDL = ';'.freeze

    def endl
      @dot << ENDL
    end

    def escape(string)
      # Backslash escaping seems to work for the backslash itself,
      # though it's not documented in the DOT language docs.
      string.gsub(/[\\"\n]/,
                  "\\" => "\\\\",
                  "\"" => "\\\"",
                  "\n" => "\\n")
    end

    def id(value)
      case string = value.to_s
      when /\A(?!\d)\w+\z/, /\A(?:\.\d+|\d+(?:\.\d*)?)\z/
        raw string
      else
        raw '"'
        raw escape(string)
        raw '"'
      end
    end

    def ids(values)
      values.each_with_index { |id, i|
        raw ' ' if i > 0
        id id
      }
    end

    def attr_list(attrs = nil)
      return if attrs.nil?
      attrs = attrs.select { |key, value| value.present? }
      return if attrs.empty?
      raw '['
      attrs.each_with_index { |(key, value), i|
        raw ',' if i > 0
        id key
        raw '='
        id value
      }
      raw ']'
    end

    def node(id, attrs = nil)
      id id
      attr_list attrs
      endl
    end

    def edge(from, to, attrs = nil, op = '->')
      id from
      raw op
      id to
      attr_list attrs
      endl
    end

    def statement(ids, attrs = nil)
      ids Array(ids)
      attr_list attrs
      endl
    end

    def block(*ids, &block)
      ids ids
      raw '{'
      block.call
      raw '}'
    end
  end

  private

  def draw(vars = {}, &block)
    DotDrawer.draw(vars, &block)
  end

  def agents_dot(agents, rich: false, layout: nil)
    draw(agents: agents,
         agent_id: ->agent { 'a%d' % agent.id },
         agent_label: ->agent {
           agent.name.gsub(/(.{20}\S*)\s+/) {
             # Fold after every 20+ characters
             $1 + "\n"
           }
         },
         agent_url: ->agent { agent_path(agent.id) },
         rich: rich) {
      @disabled = '#999999'

      def agent_node(agent)
        node(agent_id[agent],
             label: agent_label[agent],
             tooltip: (agent.short_type.titleize if rich),
             URL: (agent_url[agent] if rich),
             style: ('rounded,dashed' if agent.unavailable?),
             color: (@disabled if agent.unavailable?),
             fontcolor: (@disabled if agent.unavailable?))
      end

      def agent_edge(agent, receiver)
        edge(agent_id[agent],
             agent_id[receiver],
             style: ('dashed' unless receiver.propagate_immediately?),
             label: (" #{agent.control_action}s " if agent.can_control_other_agents?),
             arrowhead: ('empty' if agent.can_control_other_agents?),
             color: (@disabled if agent.unavailable? || receiver.unavailable?))
      end

      block('digraph', 'Agent Event Flow') {
        layout ||= ENV['DIAGRAM_DEFAULT_LAYOUT'].presence
        if rich && /\A[a-z]+\z/ === layout
          statement 'graph', layout: layout, overlap: 'false'
        end
        statement 'node',
                  shape: 'box',
                  style: 'rounded',
                  target: '_blank',
                  fontsize: 10,
                  fontname: ('Helvetica' if rich)

        statement 'edge',
                  fontsize: 10,
                  fontname: ('Helvetica' if rich)

        agents.each.with_index { |agent, index|
          agent_node(agent)

          [
            *agent.receivers,
            *(agent.control_targets if agent.can_control_other_agents?)
          ].each { |receiver|
            agent_edge(agent, receiver) if agents.include?(receiver)
          }
        }
      }
    }
  end

  def decorate_svg(xml, agents)
    svg = Nokogiri::XML(xml).at('svg')

    Nokogiri::HTML::Document.new.tap { |doc|
      doc << root = Nokogiri::XML::Node.new('div', doc) { |div|
        div['class'] = 'agent-diagram'
      }

      svg['class'] = 'diagram'

      root << svg
      root << overlay_container = Nokogiri::XML::Node.new('div', doc) { |div|
        div['class'] = 'overlay-container'
      }
      overlay_container << overlay = Nokogiri::XML::Node.new('div', doc) { |div|
        div['class'] = 'overlay'
      }

      svg.xpath('//xmlns:g[@class="node"]', svg.namespaces).each { |node|
        agent_id = (node.xpath('./xmlns:title/text()', svg.namespaces).to_s[/\d+/] or next).to_i
        agent = agents.find { |a| a.id == agent_id }

        count = agent.events_count
        next unless count && count > 0

        overlay << Nokogiri::XML::Node.new('a', doc) { |badge|
          badge['id'] = id = 'b%d' % agent_id
          badge['class'] = 'badge'
          badge['href'] = agent_events_path(agent)
          badge['target'] = '_blank'
          badge['title'] = "#{count} events created"
          badge.content = count.to_s

          node['data-badge-id'] = id

          badge << Nokogiri::XML::Node.new('span', doc) { |label|
            # a dummy label only to obtain the background color
            label['class'] = [
              'label',
              if agent.unavailable?
                'label-warning'
              elsif agent.working?
                'label-success'
              else
                'label-danger'
              end
            ].join(' ')
            label['style'] = 'display: none';
          }
        }
      }
      # See also: app/assets/diagram.js.coffee
    }.at('div.agent-diagram').to_s
  end
end
