class RenameTargetIdToControlTargetId < ActiveRecord::Migration
  def change
    rename_column :chains, :target_id, :control_target_id
  end
end
