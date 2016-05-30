module ScenarioHelper

  def style_colors(scenario)
    colors = {
      color: scenario.tag_fg_color || default_scenario_fg_color,
      background_color: scenario.tag_bg_color || default_scenario_bg_color
    }.map { |key, value| "#{key.to_s.dasherize}:#{value}" }.join(';')
  end

  def scenario_label(scenario, text = nil)
    text ||= scenario.name
    content_tag :span, text, class: 'label scenario' do 
      concat(image_tag(scenario.avatar.url(:thumb)))
    end
  end

  def default_scenario_bg_color
    '#5BC0DE'
  end

  def default_scenario_fg_color
    '#FFFFFF'
  end

end
