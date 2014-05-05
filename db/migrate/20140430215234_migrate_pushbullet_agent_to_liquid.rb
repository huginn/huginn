class MigratePushbulletAgentToLiquid < ActiveRecord::Migration
  def up
    Agent.where(:type => 'Agents::PushbulletAgent').each do |agent|
      LiquidMigrator.convert_all_agent_options(agent)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot revert migration to Liquid templating"
  end
end
