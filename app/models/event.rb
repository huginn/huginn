require 'json_serialized_field'

# Events are how Huginn Agents communicate and log information about the world.  Events can be emitted and received by
# Agents.  They contain a serialized `payload` of arbitrary JSON data, as well as optional `lat`, `lng`, and `expires_at`
# fields.
class Event < ActiveRecord::Base
  include JSONSerializedField

  attr_accessible :lat, :lng, :payload, :user_id, :user, :expires_at

  acts_as_mappable

  json_serialize :payload

  belongs_to :user
  belongs_to :agent, :counter_cache => true, :touch => :last_event_at

  scope :recent, lambda { |timespan = 12.hours.ago|
    where("events.created_at > ?", timespan)
  }

  after_create :possibly_propagate

  # Emit this event again, as a new Event.
  def reemit!
    agent.create_event :payload => payload, :lat => lat, :lng => lng
  end

  # Look for Events whose `expires_at` is present and in the past.  Remove those events and then update affected Agents'
  # `events_counts` cache columns.  This method is called by bin/schedule.rb periodically.
  def self.cleanup_expired!
    affected_agents = Event.where("expires_at IS NOT NULL AND expires_at < ?", Time.now).group("agent_id").pluck(:agent_id)
    Event.where("expires_at IS NOT NULL AND expires_at < ?", Time.now).delete_all
    Agent.where(:id => affected_agents).update_all "events_count = (select count(*) from events where agent_id = agents.id)"
  end

  protected
  def possibly_propagate
    #immediately schedule agents that want immediate updates
    propagate_ids = agent.receivers.where(:propagate_immediately => true).pluck(:id)
    Agent.receive!(:only_receivers => propagate_ids) unless propagate_ids.empty?
  end
end
