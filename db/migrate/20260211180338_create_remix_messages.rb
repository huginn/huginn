class CreateRemixMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :remix_messages, id: :integer do |t|
      t.integer :remix_id, null: false
      t.string :role, null: false
      t.text :content
      t.json :tool_calls
      t.string :tool_call_id
      t.string :tool_name

      t.timestamps
    end

    add_index :remix_messages, [:remix_id, :created_at]
    add_foreign_key :remix_messages, :remixes
  end
end
