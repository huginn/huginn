class CreateRailsAdminHistoriesTable < ActiveRecord::Migration
   def self.up
     create_table :rails_admin_histories do |t|
       t.text :message # title, name, or object_id
       t.string :username
       t.integer :item
       t.string :table
       t.integer :month, :limit => 2
       t.integer :year, :limit => 5
       t.timestamps
    end
    add_index(:rails_admin_histories, [:item, :table, :month, :year], :name => 'index_rails_admin_histories' )
  end

  def self.down
    drop_table :rails_admin_histories
  end
end
