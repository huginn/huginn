class AdoptXpathInWebsiteAgent < ActiveRecord::Migration
  def up
    Agent.where(type: 'Agents::WebsiteAgent').each do |agent|
      next if agent.extraction_type == 'json'

      agent.options_will_change!
      agent.options['extract'].each { |name, extraction|
        case
        when extraction.delete('text')
          extraction['value'] = './/text()'
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
