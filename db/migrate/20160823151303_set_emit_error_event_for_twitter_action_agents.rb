class SetEmitErrorEventForTwitterActionAgents < ActiveRecord::Migration[4.2]
  def up
    Agents::TwitterActionAgent.find_each do |agent|
      agent.options['emit_error_events'] = 'true'
      agent.save!(validate: false)
    end
  end

  def down
    Agents::TwitterActionAgent.find_each do |agent|
      agent.options.delete('emit_error_events')
      agent.save!(validate: false)
    end
  end
end
