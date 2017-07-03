class SetEventsCountDefault < ActiveRecord::Migration[4.2]
  def up
    change_column_default(:agents, :events_count, 0)
    change_column_null(:agents, :events_count, false, 0)
  end

  def down
    change_column_null(:agents, :events_count, true)
    change_column_default(:agents, :events_count, nil)
  end
end
