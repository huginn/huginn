class AddTagColorToScenarios < ActiveRecord::Migration
  def change
    add_column :scenarios, :tag_bg_color, :string, default: '#5bc0de'
    add_column :scenarios, :tag_fg_color, :string, default: '#ffffff'
  end
end
