require 'json_serialized_field'

# Events are how Huginn Agents communicate and log information about the world.  Events can be emitted and received by
# Agents.  They contain a serialized `payload` of arbitrary JSON data, as well as optional `lat`, `lng`, and `expires_at`
# fields.
class Event < ActiveRecord::Base
  include JSONSerializedField
  include LiquidDroppable

  attr_accessible :lat, :lng, :payload, :user_id, :user, :expires_at

  acts_as_mappable

  json_serialize :payload

  belongs_to :user
  belongs_to :agent, :counter_cache => true, :touch => :last_event_at

  has_many :agent_logs_as_inbound_event, :class_name => "AgentLog", :foreign_key => :inbound_event_id, :dependent => :nullify
  has_many :agent_logs_as_outbound_event, :class_name => "AgentLog", :foreign_key => :outbound_event_id, :dependent => :nullify

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

class EventDrop
  def initialize(object)
    @payload = object.payload
    super
  end

  def before_method(key)
    @payload[key]
  end

  def each(&block)
    @payload.each(&block)
  end

  def agent
    @payload.fetch(__method__) {
      @object.agent
    }
  end

  def created_at
    @payload.fetch(__method__) {
      @object.created_at
    }
  end
end
