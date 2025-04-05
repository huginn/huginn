module Agents
  class DelayAgent < Agent
    include FormConfigurable

    default_schedule 'every_12h'

    description <<~MD
      The DelayAgent stores received Events and emits copies of them on a schedule. Use this as a buffer or queue of Events.

      `max_events` should be set to the maximum number of events that you'd like to hold in the buffer. When this number is
      reached, new events will either be ignored, or will displace the oldest event already in the buffer, depending on
      whether you set `keep` to `newest` or `oldest`.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.

      `emit_interval` specifies the interval in seconds between emitting events.  This is zero (no interval) by default.

      `max_emitted_events` is used to limit the number of the maximum events which should be created. If you omit this DelayAgent will create events for every event stored in the memory.

      # Ordering Events

      #{description_events_order("events in which buffered events are emitted")}
    MD

    def default_options
      {
        'expected_receive_period_in_days' => 10,
        'max_events' => 100,
        'keep' => 'newest',
        'max_emitted_events' => '',
        'emit_interval' => 0,
        'events_order' => [],
      }
    end

    form_configurable :expected_receive_period_in_days, type: :number, html_options: { min: 1 }
    form_configurable :max_events, type: :number, html_options: { min: 1 }
    form_configurable :keep, type: :array, values: %w[newest oldest]
    form_configurable :max_emitted_events, type: :number, html_options: { min: 0 }
    form_configurable :emit_interval, type: :number, html_options: { min: 0, step: 0.001 }
    form_configurable :events_order, type: :json

    def validate_options
      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base,
                   "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end

      unless options['keep'].present? && options['keep'].in?(%w[newest oldest])
        errors.add(:base, "The 'keep' option is required and must be set to 'oldest' or 'newest'")
      end

      unless interpolated['max_events'].present? && interpolated['max_events'].to_i > 0
        errors.add(:base, "The 'max_events' option is required and must be an integer greater than 0")
      end

      if interpolated['max_emitted_events'].present?
        unless interpolated['max_emitted_events'].to_i > 0
          errors.add(:base, "The 'max_emitted_events' option is optional and should be an integer greater than 0")
        end
      end

      unless interpolated['emit_interval'] in nil | 0.. | /\A\d+(?:\.\d+)?\z/
        errors.add(:base, "The 'emit_interval' option should be a non-negative number if set")
      end
    end

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def receive(incoming_events)
      save!

      with_lock do
        incoming_events.each do |event|
          event_ids = memory['event_ids'] || []
          event_ids << event.id
          if event_ids.length > interpolated['max_events'].to_i
            if options['keep'] == 'newest'
              event_ids.shift
            else
              event_ids.pop
            end
          end
          memory['event_ids'] = event_ids
        end
      end
    end

    private def extract_emitted_events!
      save!

      with_lock do
        emitted_events = received_events.where(id: memory['event_ids']).reorder(:id).to_a

        if interpolated[SortableEvents::EVENTS_ORDER_KEY].present?
          emitted_events = sort_events(emitted_events)
        end

        max_emitted_events = interpolated['max_emitted_events'].presence&.to_i

        if max_emitted_events&.< emitted_events.length
          emitted_events[max_emitted_events..] = []
        end

        memory['event_ids'] -= emitted_events.map(&:id)
        save!

        emitted_events
      end
    end

    def check
      return if memory['event_ids'].blank?

      interval = (options['emit_interval'].presence&.to_f || 0).clamp(0..)

      extract_emitted_events!.each_with_index do |event, i|
        sleep interval unless i.zero?
        create_event payload: event.payload
      end
    end
  end
end
