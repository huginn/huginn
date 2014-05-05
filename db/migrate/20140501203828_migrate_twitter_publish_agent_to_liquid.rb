class MigrateTwitterPublishAgentToLiquid < ActiveRecord::Migration
  def up
    Agent.where(:type => 'Agents::TwitterPublishAgent').each do |agent|
      if (message = agent.options.delete('message_path')).present?
        agent.options['message'] = "{{#{message}}}"
        agent.save
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot revert migration to Liquid templating"
  end
end
