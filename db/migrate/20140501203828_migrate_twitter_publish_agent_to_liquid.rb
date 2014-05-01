class MigrateTwitterPublishAgentToLiquid < ActiveRecord::Migration
  def change
    Agent.where(:type => 'Agents::TwitterPublishAgent').each do |agent|
      if (message = agent.options.delete('message_path')).present?
        agent.options['message'] = "{{#{message}}}"
        agent.save
      end
    end
  end
end
