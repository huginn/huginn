class AddProcessingToRemixes < ActiveRecord::Migration[7.0]
  def change
    add_column :remixes, :processing, :boolean, default: false, null: false
  end
end
