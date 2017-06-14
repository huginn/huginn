# PG allows arbitrarily long text fields but MySQL has default limits. Make those limits larger if we're using MySQL.

class ChangeMemoryToLongText < ActiveRecord::Migration[4.2]
  def up
    if mysql?
      change_column :agents, :memory, :text, :limit => 4294967295
      change_column :events, :payload, :text, :limit => 16777215
    end
  end

  def down
    if mysql?
      change_column :agents, :memory, :text, :limit => 65535
      change_column :events, :payload, :text, :limit => 65535
    end
  end

  def mysql?
    ActiveRecord::Base.connection.adapter_name =~ /mysql/i
  end
end
