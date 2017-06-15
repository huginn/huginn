class AddGuidToAgents < ActiveRecord::Migration[4.2]
  class Agent < ActiveRecord::Base; end

  def change
    add_column :agents, :guid, :string

    Agent.find_each do |agent|
      agent.update_attribute :guid, SecureRandom.hex
    end

    change_column_null :agents, :guid, false

    add_index :agents, :guid
  end
end
