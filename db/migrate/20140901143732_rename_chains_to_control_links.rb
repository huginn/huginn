class RenameChainsToControlLinks < ActiveRecord::Migration
  def change
    rename_table :chains, :control_links
  end
end
