class EncryptUserCredentials < ActiveRecord::Migration[5.0]
  def change
      rename_column :user_credentials, :credential_value, :encrypted_credential_value
      add_column :user_credentials, :encrypted_credential_value_iv, :string, :default => 'text', :null => false
  end
end
