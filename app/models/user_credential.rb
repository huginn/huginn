class UserCredential < ActiveRecord::Base
  MODES = %w[text java_script]

  belongs_to :user

  validates_presence_of :credential_name
  validates_presence_of :credential_value
  validates_inclusion_of :mode, :in => MODES
  validates_presence_of :user_id
  validates_uniqueness_of :credential_name, :scope => :user_id

  before_validation :default_mode_to_text
  before_save :trim_fields

  protected

  def trim_fields
    credential_name.strip!
    credential_value.strip!
  end

  def default_mode_to_text
    self.mode = 'text' unless mode.present?
  end
end
