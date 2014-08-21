require 'spec_helper'

describe ScenarioHelper do
  let(:scenario) { users(:bob).scenarios.build(name: 'Scene', tag_fg_color: '#AAAAAA', tag_bg_color: '#000000') }

  describe '#style_colors' do
    it 'returns a css style-formated version of the scenario foreground and background colors' do
      style_colors(scenario).should == "color:#AAAAAA;background-color:#000000"
    end

    it 'defauls foreground and background colors' do
      scenario.tag_fg_color = nil
      scenario.tag_bg_color = nil
      style_colors(scenario).should == "color:#FFFFFF;background-color:#5BC0DE"
    end
  end

  describe '#scenario_label' do
    it 'creates a scenario label with the scenario name' do
      scenario_label(scenario).should ==
        '<span class="label scenario" style="color:#AAAAAA;background-color:#000000">Scene</span>'
    end

    it 'creates a scenario label with the given text' do
      scenario_label(scenario, 'Other').should ==
        '<span class="label scenario" style="color:#AAAAAA;background-color:#000000">Other</span>'
    end
  end

end
