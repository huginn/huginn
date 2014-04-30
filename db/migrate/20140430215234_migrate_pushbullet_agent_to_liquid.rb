class MigratePushbulletAgentToLiquid < ActiveRecord::Migration
  def change
    Agent.where(:type => 'Agents::PushbulletAgent').each do |agent|
      LiquidMigrator.convert_all_agent_options(agent)
    end
  end
end
