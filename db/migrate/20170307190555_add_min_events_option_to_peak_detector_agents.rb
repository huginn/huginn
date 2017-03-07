class AddMinEventsOptionToPeakDetectorAgents < ActiveRecord::Migration[5.0]
  def up
    Agents::PeakDetectorAgent.find_each do |agent|
      if agent.options['min_events'].nil?
        agent.options['min_events'] = '4'
        agent.save(validate: false)
      end
    end
  end

  def down
    Agents::PeakDetectorAgent.find_each do |agent|
      if agent.options['min_events'].present?
        agent.options.delete 'min_events'
        agent.save(validate: false)
      end
    end
  end
end
