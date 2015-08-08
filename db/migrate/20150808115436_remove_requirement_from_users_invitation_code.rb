class RemoveRequirementFromUsersInvitationCode < ActiveRecord::Migration
  def change
    change_column_null :users, :invitation_code, true, ENV['INVITATION_CODE']
  end
end
