module ScenarioHelper

  def style_colors(scenario)
    colors = {
      color: scenario.tag_fg_color,
      background_color: scenario.tag_bg_color
    }.map { |key, value| "#{key.to_s.dasherize}:#{value}" }.join(';')
  end

end
