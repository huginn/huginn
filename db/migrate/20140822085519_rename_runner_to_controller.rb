class RenameRunnerToController < ActiveRecord::Migration
  def change
    rename_column :chains, :runner_id, :controller_id
  end
end
