class AddDeactivatedAtToUsers < ActiveRecord::Migration
  def change
    add_column :users, :deactivated_at, :datetime

    add_index :users, :deactivated_at
  end
end
