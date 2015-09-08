module DotHelper
  def render_agents_diagram(agents)
    if (command = ENV['USE_GRAPHVIZ_DOT']) &&
       (svg = IO.popen([command, *%w[-Tsvg -q1 -o/dev/stdout /dev/stdin]], 'w+') { |dot|
          dot.print agents_dot(agents, true)
          dot.close_write
          dot.read
        } rescue false)
      decorate_svg(svg, agents).html_safe
    else
      uriquery = URI.encode_www_form(cht: 'gv', chl: agents_dot(agents))
      #Get query maximum length should be under 2048 bytes with including "chart?" of google chart request url
      if uriquery.length > 2042
        "Too many agent to display, please check unused agents"
      else
        tag('img', src: URI('https://chart.googleapis.com/chart').tap { |uri|
              uri.query = uriquery
	    })
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

  def agents_dot(agents, rich = false)
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
        # statement 'graph', rankdir: 'LR'
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
        div['style'] = "width: #{svg['width']}; height: #{svg['height']}; z-index: 1;"
      }
      overlay_container << overlay = Nokogiri::XML::Node.new('div', doc) { |div|
        div['class'] = 'overlay'
      }

      svg.xpath('//xmlns:g[@class="node"]', svg.namespaces).each { |node|
        agent_id = (node.xpath('./xmlns:title/text()', svg.namespaces).to_s[/\d+/] or next).to_i
        agent = agents.find { |a| a.id == agent_id }

        count = agent.events_count

        overlay << Nokogiri::XML::Node.new('div', doc) { |badge|
          badge['id'] = id = 'b%d' % agent_id
          badge['class'] = 'btn-group'
          node['data-badge-id'] = id

          badge << Nokogiri::XML::Node.new('button', doc) { |btn|
            btn['type'] = 'button'
            btn['class'] = 'btn btn-default dropdown-toggle'
            btn['data-toggle'] = 'dropdown'
            btn['aria-expanded'] = 'false'
            btn['style'] = 'width: 17px; height: 17px; background-color: #60C0F5'
            btn.content = ""

            btn << Nokogiri::XML::Node.new('span', doc) { |caret|
              caret['class'] = 'caret'
              caret['style'] = 'width: 8px; height: 8px; border-top: 8px solid; vertical-align: top; padding: 1px'
            }
          }

          badge << Nokogiri::XML::Node.new('ul', doc) { |ultag|
            ultag['class'] = 'dropdown-menu'
            ultag['role'] = 'menu'
            ultag << Nokogiri::XML::Node.new('li', doc) { |litag|
              litag<< Nokogiri::XML::Node.new('a', doc) { |atag|
                atag['href'] = agent_path(agent)
                atag<< Nokogiri::XML::Node.new('span', doc) { |spantag|
                  spantag['class'] = 'glyphicon glyphicon-eye-open'
                  spantag.content = ' Show All'
                }
              }
            }
            ultag << Nokogiri::XML::Node.new('li', doc) { |litag|
              litag['class'] = 'divider'
            }
            ultag << Nokogiri::XML::Node.new('li', doc) { |litag|
              litag<< Nokogiri::XML::Node.new('a', doc) { |atag|
                atag['href'] = '#'
                atag['data-toggle'] = 'modal'
                atag['data-target'] = '#diagramEditAgent%d' % agent_id
                atag<< Nokogiri::XML::Node.new('span', doc) { |spantag|
                  spantag['class'] = 'glyphicon glyphicon-pencil'
                  spantag.content = ' Edit agent name'
                }
              }
            }
            ultag << Nokogiri::XML::Node.new('li', doc) { |litag|
              litag<< Nokogiri::XML::Node.new('a', doc) { |atag|
                atag['href'] = edit_agent_path(agent)
                atag<< Nokogiri::XML::Node.new('span', doc) { |spantag|
                  spantag['class'] = 'glyphicon glyphicon-pencil'
                  spantag.content = ' Edit agent settings'
                }
              }
            }
            ultag << Nokogiri::XML::Node.new('li', doc) { |litag|
              litag['class'] = 'divider'
            }
            ultag << Nokogiri::XML::Node.new('li', doc) { |litag|
              litag<< Nokogiri::XML::Node.new('a', doc) { |atag|
                atag['href'] = '#'
                atag['data-toggle'] = 'modal'
                atag['data-target'] = '#diagramEnableAgent%d' % agent_id
                atag<< Nokogiri::XML::Node.new('span', doc) { |spantag|
                  if agent.disabled?
                    spantag['class'] = 'glyphicon glyphicon-play'
                    spantag.content = ' Enable agent'
                  else
                    spantag['class'] = 'glyphicon glyphicon-pause'
                    spantag.content = ' Disable agent'
                  end
                }
              }
            }
            ultag << Nokogiri::XML::Node.new('li', doc) { |litag|
              litag<< Nokogiri::XML::Node.new('a', doc) { |atag|
                atag['href'] = '#'
                atag['data-toggle'] = 'modal'
                atag['data-target'] = '#diagramSrcAgent%d' % agent_id
                atag<< Nokogiri::XML::Node.new('span', doc) { |spantag|
                  spantag['class'] = 'glyphicon glyphicon-road'
                  spantag.content = ' Set Source Agent'
                }
              }
            }
          }
          #modal for setting source agent
          root << Nokogiri::XML::Node.new('div', doc) { |div|
            div['class'] = 'confirm-agent modal'
            div['id'] = 'diagramSrcAgent%d' % agent_id
            div['tabindex'] = '-1'
            div['role'] = 'dialog'
            div['aria-labelledby'] = 'diagramSrcAgentLabel%d' % agent_id
            div['aria-hidden'] = 'true'
            div << Nokogiri::XML::Node.new('div', doc) { |divtag|
              divtag['class'] = 'modal-dialog modal-lg'
              divtag << Nokogiri::XML::Node.new('div', doc) { |divtag2nd|
                divtag2nd['class'] = 'modal-content'
                divtag2nd << Nokogiri::XML::Node.new('div', doc) { |divheader|
                  divheader['class'] = 'modal-header'
                  divheader << Nokogiri::XML::Node.new('button', doc) { |btntag|
                    btntag['class'] = 'close'
                    btntag['type'] = 'button'
                    btntag['data-dismiss'] = 'modal'
                    btntag['aria-label'] = 'Close'
                    btntag << Nokogiri::XML::Node.new('span', doc) { |spantag|
                      spantag['aria-hidden'] = 'true'
                      spantag.content = 'x'
                    }
                  }
                  divheader << Nokogiri::XML::Node.new('h4', doc) { |h4tag|
                    h4tag['class'] = 'modal-title'
                    h4tag['id'] = 'diagramSrcAgentLabel%d' % agent_id
                    h4tag.content = 'Select Source Agent('+agent.name+')'
                  }
                }
                divtag2nd << Nokogiri::XML::Node.new('div', doc) { |divbody|
                  divbody['class'] = 'modal-body'
                  divbody << Nokogiri::XML::Node.new('label', doc) { |labeltag|
                    labeltag.content = 'Source'
                  }
                  divbody << Nokogiri::XML::Node.new('div', doc) { |divtag|
                    divtag['class'] = 'col-md-10'
                    divbody << Nokogiri::XML::Node.new('form', doc) { |formtag|
                      formtag['id'] = 'edit_agent%d' % agent_id
                      formtag['class'] = 'edit_agnet'
                      formtag['method'] = 'post'
                      formtag['action'] = '/agents/%d' % agent_id+'?return=diagram'
                      formtag['accept-charset'] = 'UTF-8'
                      formtag << Nokogiri::XML::Node.new('div', doc) { |divtag2inbody|
                        divtag2inbody['style'] = 'display:none'
                        divtag2inbody << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                          inputtag['type'] = 'hidden'
                          inputtag['name'] = 'utf8'
                          inputtag['value'] = '&#x2713;'
                        }
                        divtag2inbody << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                          inputtag['type'] = 'hidden'
                          inputtag['name'] = '_method'
                          inputtag['value'] = 'PUT'
                        }
                        divtag2inbody << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                          inputtag['type'] = 'hidden'
                          inputtag['name'] = 'authenticity_token'
                          inputtag['value'] = form_authenticity_token
                        }
                      }
                      formtag << Nokogiri::XML::Node.new('div', doc) { |divtag3inbody|
                        divtag3inbody['class'] = 'form-group'
                        divtag3inbody << Nokogiri::XML::Node.new('div', doc) { |divtagindivtag3|
                          divtagindivtag3['class'] = 'link-region'
                          divtagindivtag3['data-can-receive-events'] = 'true'
                          divtagindivtag3 << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                            inputtag['type'] = 'hidden'
                            inputtag['value'] = ''
                            inputtag['name'] = 'agent[source_ids][]'
                          }
                          divtagindivtag3 << Nokogiri::XML::Node.new('select', doc) { |selecttag|
                            selecttag['class'] = 'select2 form-control'
                            selecttag['size'] = '5'
                            selecttag['multiple'] = 'multiple'
                            selecttag['name'] = 'agent[source_ids][]'
                            eventSources = (current_user.agents - [agent]).find_all { |a| a.can_create_events? }
                            sourceids = agent.source_ids
                            eventSources.map {|s|
                              selecttag << Nokogiri::XML::Node.new('option', doc) { |optiontag|
                                optiontag['value'] = s.id
                                if sourceids.include?(s.id)
                                  optiontag['selected'] = 'selected'
                                end
                                optiontag.content = s.name
                              }
                            }
                          }
                        }
                      }
                      formtag << Nokogiri::XML::Node.new('div', doc) { |divtag4inbody|
                        divtag4inbody['class'] = 'form-group'
                        divtag4inbody << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                          inputtag['class'] = 'btn btn-primary'
                          inputtag['type'] = 'submit'
                          inputtag['value'] = 'Save'
                          inputtag['name'] = 'commit'
                        }
                      }
                    }
                  }
                }
                divtag2nd << Nokogiri::XML::Node.new('div', doc) { |divfooter|
                  divfooter['class'] = 'modal-footer'
                  divfooter << Nokogiri::XML::Node.new('button', doc) { |btntag|
                    btntag['type'] = 'button'
                    btntag['class'] = 'btn btn-default'
                    btntag['data-dismiss'] = 'modal'
                    btntag.content = 'close'
                  }
                }
              }
            }
          }
          #End of #modal for setting source agent
          #modal for edit agent name
          root << Nokogiri::XML::Node.new('div', doc) { |div|
            div['class'] = 'confirm-agent modal'
            div['id'] = 'diagramEditAgent%d' % agent_id
            div['tabindex'] = '-1'
            div['role'] = 'dialog'
            div['aria-labelledby'] = 'diagramEditAgentLabel%d' % agent_id
            div['aria-hidden'] = 'true'
            div << Nokogiri::XML::Node.new('div', doc) { |divtag|
              divtag['class'] = 'modal-dialog modal-lg'
              divtag << Nokogiri::XML::Node.new('div', doc) { |divtag2nd|
                divtag2nd['class'] = 'modal-content'
                divtag2nd << Nokogiri::XML::Node.new('div', doc) { |divheader|
                  divheader['class'] = 'modal-header'
                  divheader << Nokogiri::XML::Node.new('button', doc) { |btntag|
                    btntag['class'] = 'close'
                    btntag['type'] = 'button'
                    btntag['data-dismiss'] = 'modal'
                    btntag['aria-label'] = 'Close'
                    btntag << Nokogiri::XML::Node.new('span', doc) { |spantag|
                      spantag['aria-hidden'] = 'true'
                      spantag.content = 'x'
                    }
                  }
                  divheader << Nokogiri::XML::Node.new('h4', doc) { |h4tag|
                    h4tag['class'] = 'modal-title'
                    h4tag['id'] = 'diagramEditAgentLabel%d' % agent_id
                    h4tag.content = 'Edit Agent name('+agent.name+')'
                  }
                }
                divtag2nd << Nokogiri::XML::Node.new('div', doc) { |divbody|
                  divbody['class'] = 'modal-body'
                  divbody << Nokogiri::XML::Node.new('div', doc) { |divtag|
                    divtag['class'] = 'col-md-10'
                    divbody << Nokogiri::XML::Node.new('form', doc) { |formtag|
                      formtag['id'] = 'editname_agent%d' % agent_id
                      formtag['class'] = 'editname_agentt'
                      formtag['method'] = 'post'
                      formtag['action'] = '/agents/%d' % agent_id+'?return=diagram'
                      formtag['accept-charset'] = 'UTF-8'
                      formtag << Nokogiri::XML::Node.new('div', doc) { |divtag2inbody|
                        divtag2inbody['style'] = 'display:none'
                        divtag2inbody << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                          inputtag['type'] = 'hidden'
                          inputtag['name'] = 'utf8'
                          inputtag['value'] = '&#x2713;'
                        }
                        divtag2inbody << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                          inputtag['type'] = 'hidden'
                          inputtag['name'] = '_method'
                          inputtag['value'] = 'PUT'
                        }
                        divtag2inbody << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                          inputtag['type'] = 'hidden'
                          inputtag['name'] = 'authenticity_token'
                          inputtag['value'] = form_authenticity_token
                        }
                      }
                      formtag << Nokogiri::XML::Node.new('div', doc) { |divtag3inbody|
                        divtag3inbody['class'] = 'form-group'
                        divtag3inbody << Nokogiri::XML::Node.new('label', doc) { |labeltag|
                          labeltag['for'] = 'agent_name'
                          labeltag.content = 'Name'
                        }
                        divtag3inbody << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                          inputtag['class'] = 'form-control'
                          inputtag['for'] = 'agent_name'
                          inputtag['name'] = 'agent[name]'
                          inputtag['type'] = 'text'
                          inputtag['value'] = agent.name
                        }
                      }
                      formtag << Nokogiri::XML::Node.new('div', doc) { |divtag4inbody|
                        divtag4inbody['class'] = 'form-group'
                        divtag4inbody << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                          inputtag['class'] = 'btn btn-primary'
                          inputtag['type'] = 'submit'
                          inputtag['value'] = 'Save'
                          inputtag['name'] = 'commit'
                        }
                      }
                    }
                  }
                }
                divtag2nd << Nokogiri::XML::Node.new('div', doc) { |divfooter|
                  divfooter['class'] = 'modal-footer'
                  divfooter << Nokogiri::XML::Node.new('button', doc) { |btntag|
                    btntag['type'] = 'button'
                    btntag['class'] = 'btn btn-default'
                    btntag['data-dismiss'] = 'modal'
                    btntag.content = 'close'
                  }
                }
              }
            }
          }
          #End of modal for edit agent name
          #Modal for enable/disable agent
          root << Nokogiri::XML::Node.new('div', doc) { |div|
            div['class'] = 'confirm-agent modal'
            div['id'] = 'diagramEnableAgent%d' % agent_id
            div['tabindex'] = '-1'
            div['role'] = 'dialog'
            div['aria-labelledby'] = 'diagramEnableAgentLabel%d' % agent_id
            div['aria-hidden'] = 'true'
            div << Nokogiri::XML::Node.new('div', doc) { |divtag|
              divtag['class'] = 'modal-dialog modal-sm'
              divtag << Nokogiri::XML::Node.new('div', doc) { |divtag2nd|
                divtag2nd['class'] = 'modal-content'
                divtag2nd << Nokogiri::XML::Node.new('div', doc) { |divheader|
                  divheader['class'] = 'modal-header'
                  divheader << Nokogiri::XML::Node.new('button', doc) { |btntag|
                    btntag['class'] = 'close'
                    btntag['type'] = 'button'
                    btntag['data-dismiss'] = 'modal'
                    btntag['aria-label'] = 'Close'
                    btntag << Nokogiri::XML::Node.new('span', doc) { |spantag|
                      spantag['aria-hidden'] = 'true'
                      spantag.content = 'x'
                    }
                  }
                  divheader << Nokogiri::XML::Node.new('h4', doc) { |h4tag|
                    h4tag['class'] = 'modal-title'
                    h4tag['id'] = 'diagramEditAgentLabel%d' % agent_id
                    h4tag.content = 'Confirm'
                  }
                }
                divtag2nd << Nokogiri::XML::Node.new('div', doc) { |divbody|
                  divbody['class'] = 'modal-body'
                  divbody << Nokogiri::XML::Node.new('div', doc) { |divtag|
                    divtag << Nokogiri::XML::Node.new('p', doc) { |ptag|
                      if agent.disabled?
                        ptag.content = 'Enable agent('+agent.name+') ?'
                      else
                        ptag.content = 'Disable agent('+agent.name+') ?'
                      end
                    }
                  }
                }
                divtag2nd << Nokogiri::XML::Node.new('div', doc) { |divfooter|
                  divfooter['class'] = 'modal-footer'
                  divfooter << Nokogiri::XML::Node.new('form', doc) { |formtag|
                    formtag['id'] = 'editenable_agent%d' % agent_id
                    formtag['class'] = 'enablename_agentt'
                    formtag['method'] = 'post'
                    formtag['action'] = '/agents/%d' % agent_id+'?return=diagram'
                    formtag['accept-charset'] = 'UTF-8'
                    formtag << Nokogiri::XML::Node.new('div', doc) { |divtag2inform|
                      divtag2inform['style'] = 'display:none'
                      divtag2inform << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                        inputtag['type'] = 'hidden'
                        inputtag['name'] = 'utf8'
                        inputtag['value'] = '&#x2713;'
                      }
                      divtag2inform << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                        inputtag['type'] = 'hidden'
                        inputtag['name'] = '_method'
                        inputtag['value'] = 'PUT'
                      }
                      divtag2inform << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                        inputtag['type'] = 'hidden'
                        inputtag['name'] = 'authenticity_token'
                        inputtag['value'] = form_authenticity_token
                      }
                    }

                    formtag << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                      inputtag['id'] = 'agent_disabled'
                      inputtag['type'] = 'hidden'
                      inputtag['value'] = (!agent.disabled).to_s
                      inputtag['name'] = 'agent[disabled]'
                    }

                    formtag << Nokogiri::XML::Node.new('button', doc) { |btntag|
                      btntag['class'] = 'btn btn-default'
                      btntag['type'] = 'submit'
                      btntag['name'] = 'button'
                      btntag['data-dismiss'] = 'agent[disabled]'
                      btntag.content = 'No'
                    }

                    formtag << Nokogiri::XML::Node.new('input', doc) { |inputtag|
                      inputtag['class'] = 'btn btn-primary'
                      inputtag['type'] = 'submit'
                      inputtag['value'] = 'Yes'
                      inputtag['name'] = 'commit'
                    }
                  }
                }
              }
            }
          }
          #Modal for enable/disable agent
        }
      }
      # See also: app/assets/diagram.js.coffee
    }.at('div.agent-diagram').to_s
  end
end
