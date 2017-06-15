class AddIconToScenarios < ActiveRecord::Migration[4.2]
  def change
    add_column :scenarios, :icon, :string
  end
end
