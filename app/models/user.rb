class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :lockable

  INVITATION_CODES = %w[try-huginn]

  # Virtual attribute for authenticating by either username or email
  # This is in addition to a real persisted field like 'username'
  attr_accessor :login

  ACCESSIBLE_ATTRIBUTES = [ :email, :username, :login, :password, :password_confirmation, :remember_me, :invitation_code ]

  attr_accessible *ACCESSIBLE_ATTRIBUTES
  attr_accessible *(ACCESSIBLE_ATTRIBUTES + [:admin]), :as => :admin

  validates_presence_of :username
  validates_uniqueness_of :username
  validates_format_of :username, :with => /\A[a-zA-Z0-9_-]{3,15}\Z/, :message => "can only contain letters, numbers, underscores, and dashes, and must be between 3 and 15 characters in length."
  validates_inclusion_of :invitation_code, :in => INVITATION_CODES, :message => "is not valid"

  has_many :events, :order => "events.created_at desc", :dependent => :delete_all, :inverse_of => :user
  has_many :agents, :order => "agents.created_at desc", :dependent => :destroy, :inverse_of => :user

  # Allow users to login via either email or username.
  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions).where(["lower(username) = :value OR lower(email) = :value", { :value => login.downcase }]).first
    else
      where(conditions).first
    end
  end
end
