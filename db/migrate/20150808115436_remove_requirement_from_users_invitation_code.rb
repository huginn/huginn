class RemoveRequirementFromUsersInvitationCode < ActiveRecord::Migration[4.2]
  def change
    change_column_null :users, :invitation_code, true, ENV['INVITATION_CODE'].presence || 'try-huginn'
  end
end
