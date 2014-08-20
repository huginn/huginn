require 'spec_helper'

describe ScenarioHelper do

  describe '#style_colors' do
    it 'returns a css style-formated version of the scenario foreground and background colors' do
      scenario = users(:bob).scenarios.build(tag_fg_color: '#ffffff', tag_bg_color: '#000000')
      style_colors(scenario).should == "color:#ffffff;background-color:#000000"
    end
  end

end
