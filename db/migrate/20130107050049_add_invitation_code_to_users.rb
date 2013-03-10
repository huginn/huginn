class AddInvitationCodeToUsers < ActiveRecord::Migration
  def change
    add_column :users, :invitation_code, :string, :null => false
  end
end
