module Agents
  class ArchivedAgent < Agent
    can_control_other_agents!

    description <<~MD
      The Archived Agent is a dormant and unresponsive agent that does nothing when it is run or when it receives an event.

      It serves the sole purpose of keeping an agent that has been deleted or is no longer functional in an idle state, waiting for future fixes.
    MD

    def self.should_run?
      false
    end

    def working?
      false
    end

    def control_action
      'control'
    end

    def validate_options
      if options_changed?
        errors.add(:base, "options cannot be edited")
      end

      if !disabled?
        errors.add(:base, "cannot be enabled")
      end
    end

    def check
      # Do nada
    end

    def receive(incoming_events)
      # Do nada
    end
  end
end
