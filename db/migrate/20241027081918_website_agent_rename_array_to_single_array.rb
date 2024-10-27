class WebsiteAgentRenameArrayToSingleArray < ActiveRecord::Migration[6.1]
  def up
    Agents::WebsiteAgent.find_each do |agent|
      case extract = agent.options['extract']
      when Hash
        extract.each_value do |details|
          if details.is_a?(Hash) && details.key?('array')
            details['single_array'] = details.delete('array')
          end
        end
        agent.save(validate: false)
      end
    end
  end

  def down
    Agents::WebsiteAgent.find_each do |agent|
      case extract = agent.options['extract']
      when Hash
        extract.each_value do |details|
          if details.is_a?(Hash) && details.key?('single_array')
            details['array'] = details.delete('single_array')
          end
        end
        agent.save(validate: false)
      end
    end
  end
end
