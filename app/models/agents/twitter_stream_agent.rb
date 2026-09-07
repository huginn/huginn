module Agents
  class TwitterStreamAgent < Agent
    cannot_be_scheduled!
    cannot_receive_events!

    description <<~MD
      **This Agent is no longer functional and cannot be created.**

      The Twitter Stream Agent followed the Twitter stream in real time, watching for certain keywords, or filters, that you provided.  Twitter retired the streaming API it depended on in March 2023, and streaming is now only available in paid tiers of the X API v2, which Huginn does not support.

      Existing Twitter Stream Agents are kept so that the Events they created remain available.  Delete them when they are no longer needed.
    MD

    event_description <<~MD
      This Agent no longer creates Events.  Events created in the past have a `filter` key with the matched filter, and either a `count` and `time` (in `counts` mode) or the fields of the matched Tweet (in `events` mode).
    MD

    def default_options
      {}
    end

    def validate_options
      errors.add(:base, "The Twitter Stream Agent is no longer functional and cannot be created") if new_record?
    end

    def working?
      false
    end
  end
end
