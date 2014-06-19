class Scenario < ActiveRecord::Base
  include HasGuid

  attr_accessible :name, :agent_ids, :description, :public, :source_url

  belongs_to :user, :counter_cache => :scenario_count, :inverse_of => :scenarios
  has_many :scenario_memberships, :dependent => :destroy, :inverse_of => :scenario
  has_many :agents, :through => :scenario_memberships, :inverse_of => :scenarios

  validates_presence_of :name, :user

  validate :agents_are_owned

  protected

  def agents_are_owned
    errors.add(:agents, "must be owned by you") unless agents.all? {|s| s.user == user }
  end
end
