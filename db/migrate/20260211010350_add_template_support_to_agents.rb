class AddTemplateSupportToAgents < ActiveRecord::Migration[7.0]
  def change
    add_column :agents, :template, :boolean, default: false, null: false
    add_column :agents, :template_description, :text
    add_column :agents, :template_id, :integer

    add_index :agents, :template
    add_index :agents, :template_id
  end
end
