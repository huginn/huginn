require 'liquid_migrator'

class MigrateAgentsToLiquidTemplating < ActiveRecord::Migration[4.2]
  def up
    Agent.where(:type => 'Agents::HipchatAgent').each do |agent|
      LiquidMigrator.convert_all_agent_options(agent)
    end
    Agent.where(:type => 'Agents::EventFormattingAgent').each do |agent|
      agent.options['instructions'] = LiquidMigrator.convert_hash(agent.options['instructions'], {:merge_path_attributes => true, :leading_dollarsign_is_jsonpath => true})
      agent.save
    end
    Agent.where(:type => 'Agents::PushbulletAgent').each do |agent|
      LiquidMigrator.convert_all_agent_options(agent)
    end
    Agent.where(:type => 'Agents::JabberAgent').each do |agent|
      LiquidMigrator.convert_all_agent_options(agent)
    end
    Agent.where(:type => 'Agents::DataOutputAgent').each do |agent|
      LiquidMigrator.convert_all_agent_options(agent)
    end
    Agent.where(:type => 'Agents::TranslationAgent').each do |agent|
      agent.options['content'] = LiquidMigrator.convert_hash(agent.options['content'], {:merge_path_attributes => true, :leading_dollarsign_is_jsonpath => true})
      agent.save
    end
    Agent.where(:type => 'Agents::TwitterPublishAgent').each do |agent|
      if (message = agent.options.delete('message_path')).present?
        agent.options['message'] = "{{#{message}}}"
        agent.save
      end
    end
    Agent.where(:type => 'Agents::TriggerAgent').each do |agent|
      agent.options['message'] = LiquidMigrator.convert_make_message(agent.options['message'])
      agent.save
    end
    Agent.where(:type => 'Agents::PeakDetectorAgent').each do |agent|
      agent.options['message'] = LiquidMigrator.convert_make_message(agent.options['message'])
      agent.save
    end
    Agent.where(:type => 'Agents::HumanTaskAgent').each do |agent|
      LiquidMigrator.convert_all_agent_options(agent)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot revert migration to Liquid templating"
  end
end
