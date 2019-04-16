class AddSharedmemToScenarios < ActiveRecord::Migration[5.0]
  def change
    add_column :scenarios, :shared_memory, :string
  end
end
