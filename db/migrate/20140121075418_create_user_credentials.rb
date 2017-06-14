class CreateUserCredentials < ActiveRecord::Migration[4.2]
  def change
    create_table :user_credentials do |t|
      t.integer :user_id,         :null => false
      t.string :credential_name,  :null => false
      t.text :credential_value,   :null => false

      t.timestamps
    end
    add_index :user_credentials, [:user_id, :credential_name], :unique => true
  end
end
