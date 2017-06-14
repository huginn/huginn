class AddEventIdAtCreationToLinks < ActiveRecord::Migration[4.2]
  class Link < ActiveRecord::Base; end
  class Event < ActiveRecord::Base; end

  def up
    add_column :links, :event_id_at_creation, :integer, :null => false, :default => 0

    Link.all.find_each do |link|
      last_event_id = execute(
        <<-SQL
          SELECT #{ActiveRecord::Base.connection.quote_column_name('id')}
          FROM #{ActiveRecord::Base.connection.quote_table_name('events')}
          WHERE events.agent_id = #{link.source_id} ORDER BY events.id DESC limit 1
        SQL
      ).first.to_a.first
      if last_event_id.nil?
        link.event_id_at_creation = Event.last.id
      else
        link.event_id_at_creation = last_event_id
      end
      link.save
    end
  end

  def down
    remove_column :links, :event_id_at_creation
  end
end
