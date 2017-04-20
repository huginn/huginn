class SetRssContentType < ActiveRecord::Migration[5.0]
  def up
    Agents::DataOutputAgent.find_each do |agent|
      if agent.options['rss_content_type'].nil?
        agent.options['rss_content_type'] = 'text/xml'
        agent.save(validate: false)
      end
    end
  end

  def down
    Agents::DataOutputAgent.find_each do |agent|
      if agent.options.delete('rss_content_type')
        agent.save(validate: false)
      end
    end
  end
end
