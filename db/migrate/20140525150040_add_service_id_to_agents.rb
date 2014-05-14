class AddServiceIdToAgents < ActiveRecord::Migration
  def change
    add_column :agents, :service_id, :integer
  end
end
