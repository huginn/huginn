class AddXmlNamespaceOptionToDataOutputAgents < ActiveRecord::Migration[4.2]
  def up
    Agents::DataOutputAgent.find_each do |agent|
      agent.options['ns_media'] = 'true'
      agent.options['ns_itunes'] = 'true'
      agent.save!(validate: false)
    end
  end

  def down
    Agents::DataOutputAgent.find_each do |agent|
      agent.options.delete 'ns_media'
      agent.options.delete 'ns_itunes'
      agent.save!(validate: false)
    end
  end
end
