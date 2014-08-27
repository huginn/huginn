class RemoveServiceIndexOnUserId < ActiveRecord::Migration
  def change
    remove_index :services, :user_id
  end
end
