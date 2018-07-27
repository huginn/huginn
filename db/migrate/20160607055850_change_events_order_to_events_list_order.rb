class ChangeEventsOrderToEventsListOrder < ActiveRecord::Migration[4.2]
  def up
    Agents::DataOutputAgent.find_each do |agent|
      if value = agent.options.delete('events_order')
        agent.options['events_list_order'] = value
        agent.save!(validate: false)
      end
    end
  end

  def down
    Agents::DataOutputAgent.transaction do
      Agents::DataOutputAgent.find_each do |agent|
        if agent.options['events_order']
          raise ActiveRecord::IrreversibleMigration, "Cannot revert migration because events_order is configured"
        end

        if value = agent.options.delete('events_list_order')
          agent.options['events_order'] = value
          agent.save!(validate: false)
        end
      end
    end
  end
end
