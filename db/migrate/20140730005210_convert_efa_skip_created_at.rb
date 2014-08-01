class ConvertEfaSkipCreatedAt < ActiveRecord::Migration
  def up
    Agent.where(type: 'Agents::EventFormattingAgent').each do |agent|
      agent.options_will_change!
      unless agent.options.delete('skip_created_at').to_s == 'true'
        agent.options['instructions'] = {
          'created_at' => '{{created_at}}'
        }.update(agent.options['instructions'] || {})
      end
      agent.save!
    end
  end

  def down
    Agent.where(type: 'Agents::EventFormattingAgent').each do |agent|
      agent.options_will_change!
      agent.options['skip_created_at'] = (agent.options['instructions'] || {})['created_at'] == '{{created_at}}'
      agent.save!
    end
  end
end
