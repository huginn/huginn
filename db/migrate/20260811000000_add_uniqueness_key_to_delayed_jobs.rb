class AddUniquenessKeyToDelayedJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :delayed_jobs, :uniqueness_key, :string
    add_index :delayed_jobs, :uniqueness_key, unique: true
  end
end
