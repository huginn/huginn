class AddModeToUserCredentials < ActiveRecord::Migration[4.2]
  def change
    add_column :user_credentials, :mode, :string, :default => 'text', :null => false
  end
end
