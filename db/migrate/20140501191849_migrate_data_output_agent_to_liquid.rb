class MigrateDataOutputAgentToLiquid < ActiveRecord::Migration
  def change
    Agent.where(:type => 'Agents::DataOutputAgent').each do |agent|
      LiquidMigrator.convert_all_agent_options(agent)
    end
  end
end
