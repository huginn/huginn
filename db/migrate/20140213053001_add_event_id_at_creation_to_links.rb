class AddEventIdAtCreationToLinks < ActiveRecord::Migration
  def up
    add_column :links, :event_id_at_creation, :integer, :null => false, :default => 0

    execute <<-SQL
      UPDATE #{ActiveRecord::Base.connection.quote_table_name('links')}
      SET event_id_at_creation = (
        SELECT #{ActiveRecord::Base.connection.quote_column_name('id')}
        FROM #{ActiveRecord::Base.connection.quote_table_name('events')}
        WHERE events.agent_id = links.source_id ORDER BY events.id DESC limit 1
      )
    SQL
  end

  def down
    remove_column :links, :event_id_at_creation
  end
end
