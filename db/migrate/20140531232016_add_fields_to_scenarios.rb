class AddFieldsToScenarios < ActiveRecord::Migration[4.2]
  def change
    add_column :scenarios, :description, :text
    add_column :scenarios, :public, :boolean, :default => false, :null => false
    add_column :scenarios, :guid, :string
    change_column :scenarios, :guid, :string, :null => false
    add_column :scenarios, :source_url, :string
  end
end
