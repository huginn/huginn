class MigrateGrowlAgentToLiquid < ActiveRecord::Migration[5.1]
  def up
    Agents::GrowlAgent.find_each do |agent|
      agent.options['subject'] = '{{subject}}' if agent.options['subject'].blank?
      agent.options['message'] = '{{ message | default: text }}' if agent.options['message'].blank?
      agent.save(validate: false)
    end
  end

  def down
    Agents::GrowlAgent.find_each do |agent|
      %w(subject message sticky priority).each do |key|
        agent.options.delete(key)
      end
      agent.save(validate: false)
    end
  end
end
