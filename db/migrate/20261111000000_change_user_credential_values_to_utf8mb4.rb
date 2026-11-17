class ChangeUserCredentialValuesToUtf8mb4 < ActiveRecord::Migration[8.1]
  # SetCharsetForMysql left credential_value in 3-byte utf8, so MySQL stores
  # 4-byte characters such as most emoji as "?".
  def up
    return unless connection.adapter_name.match?(/mysql/i)

    change_column :user_credentials, :credential_value, :text, null: false, charset: 'utf8mb4', collation: 'utf8mb4_bin'
  end

  def down
    # Do nada; utf8 may not be able to hold the values anymore.
  end
end
