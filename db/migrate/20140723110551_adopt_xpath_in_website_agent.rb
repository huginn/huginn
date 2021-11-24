class AdoptXpathInWebsiteAgent < ActiveRecord::Migration[4.2]
  class Agent < ActiveRecord::Base
    include JsonSerializedField
    json_serialize :options
  end

  def up
    Agent.where(type: 'Agents::WebsiteAgent').each do |agent|
      extract = agent.options['extract']
      next unless extract.is_a?(Hash) && extract.all? { |name, detail|
        detail.key?('xpath') || detail.key?('css')
      }

      agent.options_will_change!
      agent.options['extract'].each { |name, extraction|
        case
        when extraction.delete('text')
          extraction['value'] = 'string(.)'
        when attr = extraction.delete('attr')
          extraction['value'] = "@#{attr}"
        end
      }
      agent.save!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot revert this migration"
  end
end
