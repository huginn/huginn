class AddUsernameToUsers < ActiveRecord::Migration[4.2]
  class User < ActiveRecord::Base
  end

  def up
    add_column :users, :username, :string

    User.find_each do |user|
      user.update_attribute :username, user.email.gsub(/@.*$/, '')
    end

    change_column :users, :username, :string, :null => false
    add_index :users, :username, :unique => true
  end

  def down
    remove_column :users, :username
  end
end
