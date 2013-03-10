class ChangeMemoryToLongText < ActiveRecord::Migration
  def up
    change_column :agents, :memory, :text, :limit => 4294967295
    change_column :events, :payload, :text, :limit => 16777215
  end

  def down
    change_column :agents, :memory, :text, :limit => 65535
    change_column :events, :payload, :text, :limit => 65535
  end
end
