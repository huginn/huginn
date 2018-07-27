class AddServiceIdToAgents < ActiveRecord::Migration[4.2]
  def change
    add_column :agents, :service_id, :integer
  end
end
