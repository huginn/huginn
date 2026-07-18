class CreateRemixes < ActiveRecord::Migration[7.0]
  def change
    create_table :remixes, id: :integer do |t|
      t.integer :user_id, null: false
      t.string :title
      t.text :system_context_cache

      t.timestamps
    end

    add_index :remixes, [:user_id, :updated_at]
    add_foreign_key :remixes, :users
  end
end
