class ConvertWebsiteAgentTemplateForMerge < ActiveRecord::Migration[5.0]
  def up
    Agents::WebsiteAgent.find_each do |agent|
      extract = agent.options['extract'].presence
      template = agent.options['template'].presence
      next unless extract.is_a?(Hash) && template.is_a?(Hash)

      (extract.keys - template.keys).each do |key|
        extract[key]['hidden'] = true
      end

      template.delete_if { |key, value|
        extract.key?(key) &&
          value.match(/\A\{\{\s*#{Regexp.quote(key)}\s*\}\}\z/)
      }

      agent.save!(validate: false)
    end
  end

  def down
    Agents::WebsiteAgent.find_each do |agent|
      extract = agent.options['extract'].presence
      template = agent.options['template'].presence
      next unless extract.is_a?(Hash) && template.is_a?(Hash)

      (extract.keys - template.keys).each do |key|
        unless extract[key].delete('hidden').in?([true, 'true'])
          template[key] = "{{ #{key} }}"
        end
      end

      agent.save!(validate: false)
    end
  end
end
