module ApplicationHelper
  def icon_tag(name, options = {})
    if dom_class = options[:class]
      dom_class = ' ' << dom_class
    end

    case name
    when /\Aglyphicon-/
      "<span class='glyphicon #{name}#{dom_class}'></span>".html_safe
    when /\Afa-/
      "<i class='fa #{name}#{dom_class}'></i>".html_safe
    else
      raise "Unrecognized icon name: #{name}"
    end
  end

  def nav_link(name, path, options = {}, &block)
    content = link_to(name, path, options)
    active = current_page?(path)
    if block
      # Passing a block signifies that the link is a header of a hover
      # menu which contains what's in the block.
      begin
        @nav_in_menu = true
        @nav_link_active = active
        content += capture(&block)
        class_name = "dropdown dropdown-hover #{@nav_link_active ? 'active' : ''}"
      ensure
        @nav_in_menu = @nav_link_active = false
      end
    else
      # Mark the menu header active if it contains the current page
      @nav_link_active ||= active if @nav_in_menu
      # An "active" menu item may be an eyesore, hence `!@nav_in_menu &&`.
      class_name = !@nav_in_menu && active ? 'active' : ''
    end
    content_tag :li, content, class: class_name
  end

  def yes_no(bool)
    content_tag :span, bool ? 'Yes' : 'No', class: "label #{bool ? 'label-info' : 'label-default' }"
  end

  def working(agent)
    if agent.disabled?
      link_to 'Disabled', agent_path(agent), class: 'label label-warning'
    elsif agent.dependencies_missing?
      content_tag :span, 'Missing Gems', class: 'label label-danger'
    elsif agent.working?
      content_tag :span, 'Yes', class: 'label label-success'
    else
      link_to 'No', agent_path(agent, tab: (agent.recent_error_logs? ? 'logs' : 'details')), class: 'label label-danger'
    end
  end

  def omniauth_provider_icon(provider)
    case provider.to_sym
    when :twitter, :tumblr, :github, :dropbox
      icon_tag("fa-#{provider}")
    when :wunderlist
      icon_tag("fa-list")
    else
      icon_tag("fa-lock")
    end
  end

  def omniauth_provider_name(provider)
    t("devise.omniauth_providers.#{provider}")
  end

  def omniauth_button(provider)
    link_to [
      omniauth_provider_icon(provider),
      content_tag(:span, "Authenticate with #{omniauth_provider_name(provider)}")
    ].join.html_safe, user_omniauth_authorize_path(provider), class: "btn btn-default btn-service service-#{provider}"
  end

  def service_label_text(service)
    "#{omniauth_provider_name(service.provider)} - #{service.name}"
  end

  def service_label(service)
    return if service.nil?
    content_tag :span, [
      omniauth_provider_icon(service.provider),
      service_label_text(service)
    ].join.html_safe, class: "label label-default label-service service-#{service.provider}"
  end

  def load_ace_editor!
    unless content_for?(:ace_editor_script)
      content_for :ace_editor_script, javascript_include_tag('ace')
    end
  end

  def highlighted?(id)
    @highlighted_ranges ||=
      case value = params[:hl].presence
      when String
        value.split(/,/).flat_map { |part|
          case part
          when /\A(\d+)\z/
            (part.to_i)..(part.to_i)
          when /\A(\d+)?-(\d+)?\z/
            ($1 ? $1.to_i : 1)..($2 ? $2.to_i : Float::INFINITY)
          else
            []
          end
        }
      else
        []
      end

    @highlighted_ranges.any? { |range| range.cover?(id) }
  end
end
