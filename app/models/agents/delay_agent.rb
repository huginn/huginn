module Agents
  class DelayAgent < Agent
    default_schedule "every_12h"

    DEFAULT_EVENTS_ORDER = [["{{event_id}}", "number"]]

    description <<-MD
      The DelayAgent stores received Events and emits copies of them on a schedule. Use this as a buffer or queue of Events.

      `max_events` should be set to the maximum number of events that you'd like to hold in the buffer. When this number is
      reached, new events will either be ignored, or will displace the oldest event already in the buffer, depending on
      whether you set `keep` to `newest` or `oldest`.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.

      `shuffle` is used to emit events in random order. Set to true to enable shuffling the events before emitting them. By default it's false.

      # Ordering Events

      #{description_events_order}

      In this Agent, the default value for `events_order` is `#{DEFAULT_EVENTS_ORDER.to_json}`.

    MD

    def default_options
      {
        'expected_receive_period_in_days' => "10",
        'max_events' => "100",
        'keep' => 'newest'
      }
    end

    def validate_options
      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end

      unless options['keep'].present? && options['keep'].in?(%w[newest oldest])
        errors.add(:base, "The 'keep' option is required and must be set to 'oldest' or 'newest'")
      end

      unless options['max_events'].present? && options['max_events'].to_i > 0
        errors.add(:base, "The 'max_events' option is required and must be an integer greater than 0")
      end

      validate_events_order
    end

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        memory['event_ids'] ||= []
        memory['event_ids'] << event.id
        if memory['event_ids'].length > interpolated['max_events'].to_i
          if interpolated['keep'] == 'newest'
            memory['event_ids'].shift
          else
            memory['event_ids'].pop
          end
        end
      end
    end

    def check
      if memory['event_ids'] && memory['event_ids'].length > 0
        events = received_events.where(id: memory['event_ids'])

        events = sort_events(events)

        events.each do |event|
          create_event payload: event.payload
        end
        memory['event_ids'] = []
      end
    end

    def events_order
      options["events_order"] || DEFAULT_EVENTS_ORDER
    end
  end
end
