class AddLastWebhookAtToAgents < ActiveRecord::Migration[4.2]
  def change
    add_column :agents, :last_webhook_at, :datetime
  end
end
