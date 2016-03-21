class AddConfirmableAttributesToUsers < ActiveRecord::Migration
  def change
    change_table(:users) do |t|
      ## Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email # Only if using reconfirmable
    end

    add_index :users, :confirmation_token,   unique: true

    if ENV['REQUIRE_CONFIRMED_EMAIL'] != 'true' && ActiveRecord::Base.connection.column_exists?(:users, :confirmed_at)
      User.update_all('confirmed_at = NOW()')
    end
  end
end
