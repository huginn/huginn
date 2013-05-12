class AddLastWebhookAtToAgents < ActiveRecord::Migration
  def change
    add_column :agents, :last_webhook_at, :datetime
  end
end
