# Removes cross-user private Service bindings created before ownership validation.
class DisconnectUnauthorizedAgentServices < ActiveRecord::Migration[8.1]
  def up
    migration_agent = Class.new(ActiveRecord::Base) do
      self.table_name = "agents"
      self.inheritance_column = nil
    end
    migration_service = Class.new(ActiveRecord::Base) do
      self.table_name = "services"
    end

    private_service_owners = migration_service.where(global: [false, nil]).pluck(:id, :user_id).to_h
    migration_agent.where(service_id: private_service_owners.keys).find_each do |agent|
      next if agent.user_id == private_service_owners.fetch(agent.service_id)

      agent.update_columns(service_id: nil, disabled: true)
    end
  end
end
