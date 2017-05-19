class ConvertEfaSkipAgent < ActiveRecord::Migration[4.2]
  def up
    Agent.where(type: 'Agents::EventFormattingAgent').each do |agent|
      agent.options_will_change!
      unless agent.options.delete('skip_agent').to_s == 'true'
        agent.options['instructions'] = {
          'agent' => '{{agent.type}}'
        }.update(agent.options['instructions'] || {})
      end
      agent.save!
    end
  end

  def down
    Agent.where(type: 'Agents::EventFormattingAgent').each do |agent|
      agent.options_will_change!
      agent.options['skip_agent'] = (agent.options['instructions'] || {})['agent'] == '{{agent.type}}'
      agent.save!
    end
  end
end
