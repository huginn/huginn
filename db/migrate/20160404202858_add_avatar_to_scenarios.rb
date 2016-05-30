class AddAvatarToScenarios < ActiveRecord::Migration
  def up
    add_attachment :scenarios, :avatar
  end

  def self.down
    remove_attachment :scenarios, :avatar
  end
end
