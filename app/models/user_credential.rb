class UserCredential < ActiveRecord::Base
  attr_accessible :credential_name, :credential_value, :user_id
  belongs_to :user
  validates_presence_of :credential_name
  validates_uniqueness_of :credential_name, :scope => :user_id
end
