# Huginn is designed to be a multi-User system.  Users have many Agents (and Events created by those Agents).
class User < ActiveRecord::Base
  DEVISE_MODULES = [:database_authenticatable, :registerable,
                    :recoverable, :rememberable, :trackable,
                    :validatable, :lockable, :omniauthable,
                    (ENV['REQUIRE_CONFIRMED_EMAIL'] == 'true' ? :confirmable : nil)].compact
  devise *DEVISE_MODULES

  INVITATION_CODES = [ENV['INVITATION_CODE'] || 'try-huginn']

  # Virtual attribute for authenticating by either username or email
  # This is in addition to a real persisted field like 'username'
  attr_accessor :login

  validates_presence_of :username
  validates :username, uniqueness: { case_sensitive: false }
  validates_format_of :username, :with => /\A[a-zA-Z0-9_-]{3,190}\Z/, :message => "can only contain letters, numbers, underscores, and dashes, and must be between 3 and 190 characters in length."
  validates_inclusion_of :invitation_code, :on => :create, :in => INVITATION_CODES, :message => "is not valid", if: -> { !requires_no_invitation_code? && User.using_invitation_code? }

  has_many :user_credentials, :dependent => :destroy, :inverse_of => :user
  has_many :events, -> { order("events.created_at desc") }, :dependent => :delete_all, :inverse_of => :user
  has_many :agents, -> { order("agents.created_at desc") }, :dependent => :destroy, :inverse_of => :user
  has_many :logs, :through => :agents, :class_name => "AgentLog"
  has_many :scenarios, :inverse_of => :user, :dependent => :destroy
  has_many :services, -> { by_name('asc') }, :dependent => :destroy

  def available_services
    Service.available_to_user(self).by_name
  end

  # Allow users to login via either email or username.
  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions).where(["lower(username) = :value OR lower(email) = :value", { :value => login.downcase }]).first
    else
      where(conditions).first
    end
  end

  def active?
    !deactivated_at
  end

  def deactivate!
    User.transaction do
      agents.update_all(deactivated: true)
      update_attribute(:deactivated_at, Time.now)
    end
  end

  def activate!
    User.transaction do
      agents.update_all(deactivated: false)
      update_attribute(:deactivated_at, nil)
    end
  end

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :deactivated_account
  end

  def self.using_invitation_code?
    ENV['SKIP_INVITATION_CODE'] != 'true'
  end

  def requires_no_invitation_code!
    @requires_no_invitation_code = true
  end

  def requires_no_invitation_code?
    !!@requires_no_invitation_code
  end

  def undefined_agent_types
    agents.reorder('').group(:type).pluck(:type).select do |type|
      begin
        type.constantize
        false
      rescue NameError
        true
      end
    end
  end

  def undefined_agents
    agents.where(type: undefined_agent_types).select('id, schedule, events_count, type as undefined')
  end
end
