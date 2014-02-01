class UserCredential < ActiveRecord::Base
  attr_accessible :credential_name, :credential_value

  belongs_to :user

  validates_presence_of :credential_name
  validates_presence_of :credential_value
  validates_presence_of :user_id
  validates_uniqueness_of :credential_name, :scope => :user_id

  before_save :trim_fields

  protected

  def trim_fields
    credential_name.strip!
    credential_value.strip!
  end
end
