class AddTagColorToScenarios < ActiveRecord::Migration
  def change
    add_column :scenarios, :tag_bg_color, :string
    add_column :scenarios, :tag_fg_color, :string
  end
end
