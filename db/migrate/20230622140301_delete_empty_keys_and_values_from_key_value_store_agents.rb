class DeleteEmptyKeysAndValuesFromKeyValueStoreAgents < ActiveRecord::Migration[6.1]
  def up
    Agents::KeyValueStoreAgent.find_each do |agent|
      agent.memory.delete_if { |key, value| key.empty? || value.nil? || value.try(:empty?) }
      agent.save!
    end
  end
end
