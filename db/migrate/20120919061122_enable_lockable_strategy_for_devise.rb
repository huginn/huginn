class EnableLockableStrategyForDevise < ActiveRecord::Migration[4.2]
  def up
    add_column :users, :failed_attempts, :integer, :default => 0
    add_column :users, :unlock_token, :string
    add_column :users, :locked_at, :datetime

    add_index :users, :unlock_token, :unique => true
  end

  def down
    remove_column :users, :failed_attempts
    remove_column :users, :unlock_token
    remove_column :users, :locked_at
  end
end
