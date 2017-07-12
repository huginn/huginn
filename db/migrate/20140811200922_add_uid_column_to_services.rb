class AddUidColumnToServices < ActiveRecord::Migration[4.2]
  def change
    add_column :services, :uid, :string
    add_index :services, :uid
    add_index :services, :provider
  end
end
