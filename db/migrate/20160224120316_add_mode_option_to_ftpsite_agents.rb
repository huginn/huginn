class AddModeOptionToFtpsiteAgents < ActiveRecord::Migration[4.2]
  def up
    Agents::FtpsiteAgent.find_each do |agent|
      agent.options['mode'] = 'read'
      agent.save!(validate: false)
    end
  end

  def down
    Agents::FtpsiteAgent.find_each do |agent|
      agent.options.delete 'mode'
      agent.save!(validate: false)
    end
  end
end
