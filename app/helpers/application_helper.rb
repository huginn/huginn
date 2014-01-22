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

  def link_to_remove_fields(name, f, options = {})
    f.hidden_field(:_destroy) + link_to_function(name, "remove_fields(this)", options)
  end

  def link_to_add_fields(name, f, options = {})
    association = options[:association]   
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(association.to_s.singularize + "_fields", :f => builder)
    end
    link_to_function(name, "add_fields(this, \"#{association}\", \"#{escape_javascript(fields)}\")")
  end
  
end
