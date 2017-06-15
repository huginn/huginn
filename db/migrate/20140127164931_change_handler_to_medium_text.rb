# Increase handler size to 16MB (consistent with events.payload)

class ChangeHandlerToMediumText < ActiveRecord::Migration[4.2]
  def up
    if mysql?
      change_column :delayed_jobs, :handler, :text, :limit => 16777215
    end
  end

  def down
    if mysql?
      change_column :delayed_jobs, :handler, :text, :limit => 65535
    end
  end

  def mysql?
    ActiveRecord::Base.connection.adapter_name =~ /mysql/i
  end
end
