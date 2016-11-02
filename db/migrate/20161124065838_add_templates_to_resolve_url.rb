class AddTemplatesToResolveUrl < ActiveRecord::Migration[5.0]
  def up
    Agents::WebsiteAgent.find_each do |agent|
      if agent.event_keys.try!(:include?, 'url')
        agent.options['template'] = (agent.options['template'] || {}).tap { |template|
          template['url'] ||= '{{ url | to_uri: _response_.url }}'
        }
        agent.save!(validate: false)
      end
    end
  end

  def down
    # No need to revert
  end
end
