class UserCredential < ActiveRecord::Base
  MODES = %w[text java_script]

  belongs_to :user

  validates :credential_name, presence: true, uniqueness: { case_sensitive: true, scope: :user_id }
  validates :credential_value, presence: true
  validates :mode, inclusion: { in: MODES }
  validates :user_id, presence: true

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
