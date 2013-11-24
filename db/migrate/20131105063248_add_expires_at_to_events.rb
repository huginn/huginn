class AddExpiresAtToEvents < ActiveRecord::Migration
  def change
    add_column :events, :expires_at, :datetime
    add_index :events, :expires_at
  end
end
