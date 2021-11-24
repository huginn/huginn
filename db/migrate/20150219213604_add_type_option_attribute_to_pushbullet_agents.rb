class AddTypeOptionAttributeToPushbulletAgents < ActiveRecord::Migration[4.2]
  def up
    Agents::PushbulletAgent.find_each do |agent|
      if agent.options['type'].nil?
        agent.options['type'] = 'note'
        agent.save!
      end
    end
  end

  def down
    Agents::PushbulletAgent.find_each do |agent|
      if agent.options['type'].present?
        agent.options.delete 'type'
        agent.save(validate: false)
      end
    end
  end
end
