require 'rails_helper'

describe ScenarioHelper do
  let(:scenario) { users(:bob).scenarios.build(name: 'Scene', tag_fg_color: '#AAAAAA', tag_bg_color: '#000000') }

  describe '#style_colors' do
    it 'returns a css style-formated version of the scenario foreground and background colors' do
      expect(style_colors(scenario)).to eq("color:#AAAAAA;background-color:#000000")
    end

    it 'defauls foreground and background colors' do
      scenario.tag_fg_color = nil
      scenario.tag_bg_color = nil
      expect(style_colors(scenario)).to eq("color:#FFFFFF;background-color:#5BC0DE")
    end
  end

  describe '#scenario_label' do
    it 'creates a scenario label with the scenario name' do
      expect(scenario_label(scenario)).to eq(
        '<span class="label scenario" style="color:#AAAAAA;background-color:#000000">Scene</span>'
      )
    end

    it 'creates a scenario label with the given text' do
      expect(scenario_label(scenario, 'Other')).to eq(
        '<span class="label scenario" style="color:#AAAAAA;background-color:#000000">Other</span>'
      )
    end
  end

end
