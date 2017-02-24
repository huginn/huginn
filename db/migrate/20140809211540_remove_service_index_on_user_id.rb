class RemoveServiceIndexOnUserId < ActiveRecord::Migration[4.2]
  def change
    remove_index :services, :user_id
  end
end
