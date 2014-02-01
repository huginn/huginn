class CreateUserCredentials < ActiveRecord::Migration
  def change
    create_table :user_credentials do |t|
      t.integer :user_id
      t.string :credential_name
      t.string :credential_value

      t.timestamps
    end
    add_index :user_credentials, [:user_id, :credential_name], :unique => true
  end
end
