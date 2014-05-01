class MigrateJabberAgentToLiquid < ActiveRecord::Migration
  def change
    Agent.where(:type => 'Agents::JabberAgent').each do |agent|
      LiquidMigrator.convert_all_agent_options(agent)
    end
  end
end
