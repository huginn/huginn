class WebsiteAgentDoesNotUseEventUrl < ActiveRecord::Migration
  def up
    # Until this migration, if a WebsiteAgent received Events and did not have a `url_from_event` option set,
    # it would use the `url` from the Event's payload.  If the Event did not have a `url` in its payload, the
    # WebsiteAgent would do nothing. This migration assumes that if someone has wired a WebsiteAgent to receive Events
    # and has not set `url_from_event` or `data_from_event`, they were trying to use the Event's `url` payload, so we
    # set `url_from_event` to `{{ url }}` for them.
    Agents::WebsiteAgent.find_each do |agent|
      next unless agent.sources.count > 0

      if !agent.options['data_from_event'].present? && !agent.options['url_from_event'].present?
        agent.options['url_from_event'] = '{{ url }}'
        agent.save!
        puts ">> Setting `url_from_event` on WebsiteAgent##{agent.id} to {{ url }} because it is wired"
        puts ">> to receive Events, and the WebsiteAgent no longer uses the Event's `url` value directly."
      end
    end
  end

  def down
  end
end
