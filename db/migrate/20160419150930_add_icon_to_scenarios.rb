class AddIconToScenarios < ActiveRecord::Migration
  def change
    add_column :scenarios, :icon, :string
  end
end
