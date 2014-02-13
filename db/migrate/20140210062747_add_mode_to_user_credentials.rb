class AddModeToUserCredentials < ActiveRecord::Migration
  def change
    add_column :user_credentials, :mode, :string, :default => 'text', :null => false
  end
end
