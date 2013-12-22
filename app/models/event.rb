require 'serialize_and_normalize'

class Event < ActiveRecord::Base
  include SerializeAndNormalize

  attr_accessible :lat, :lng, :payload, :user_id, :user, :expires_at

  acts_as_mappable

  serialize_and_normalize :payload

  belongs_to :user
  belongs_to :agent, :counter_cache => true

  scope :recent, lambda { |timespan = 12.hours.ago|
    where("events.created_at > ?", timespan)
  }

  def reemit!
    agent.create_event :payload => payload, :lat => lat, :lng => lng
  end

  def self.cleanup_expired!
    Event.where("expires_at IS NOT NULL AND expires_at < ?", Time.now).delete_all
  end
end
