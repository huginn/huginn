require 'json_serialized_field'

# PendingEvents are how Huginn Agents communicate and log information about the world.  PendingEvents can be emitted and received by
# Agents.  They should have all of the attributes Events will need to have.
class PendingEvent < ActiveRecord::Base
  include JSONSerializedField

  attr_accessible :lat, :lng, :payload, :user_id, :user, :emits_at, :scheduled

  acts_as_mappable

  json_serialize :payload

  belongs_to :user
  belongs_to :agent

  # Emit this event again, as a new Event.
  # once we have successfully emitted the event, we can delete it
  def emit!
    agent.create_event :payload => payload, :lat => lat, :lng => lng
    PendingEvent.delete(self.id)
  end

  def scheduled!
     self.scheduled = true
     save!
  end

  # Look for PendingEvents whose `emits_at` is present and in the past. Emit those events to the Event table
  # `events_counts` cache columns.  This method is called by bin/schedule.rb periodically.
  class << self
     def unscheduled
       PendingEvent.where("scheduled = ?", false)
     end

     def emit_all_pending!
       pend_events = PendingEvent.where("emits_at < ?", Time.now)
       pend_events.each do |pe|
          pe.emit!
          PendingEvent.destroy(pe.id)
       end
     end
  end
end
