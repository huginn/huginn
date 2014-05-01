class MigrateTranslationAgentToLiquid < ActiveRecord::Migration
  def change
    Agent.where(:type => 'Agents::TranslationAgent').each do |agent|
      agent.options['content'] = LiquidMigrator.convert_hash(agent.options['content'], {:merge_path_attributes => true, :leading_dollarsign_is_jsonpath => true})
      agent.save
    end
  end
end
