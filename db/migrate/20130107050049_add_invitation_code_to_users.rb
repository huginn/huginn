class AddInvitationCodeToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :invitation_code, :string
    change_column :users, :invitation_code, :string, :null => false
  end
end
