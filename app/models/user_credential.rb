class UserCredential < ActiveRecord::Base
  attr_accessible :credential_name, :credential_value, :user_id
  belongs_to :user
end
