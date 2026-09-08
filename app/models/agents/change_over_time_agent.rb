require 'date'
require 'time'

module Agents
  class ChangeOverTimeAgent < Agent
    cannot_be_scheduled!

    description <<-MD
      Computes the change of a value in the received events over time and stores
      it in a new event. For example, if you have an agent that creates events
      tracking the filling level of some container, you can use the
      ChangeOverTimeAgent to compute the actual consumption rate.
      Specifically, the agent emits a new event containing a value that is the
      difference of the values of the two last received events divided by
      the difference of their timestamps.

      Options:

        * `expected_receive_period_in_days` - How often you expect to receive
            events this way. Used to determine if the agent is working.
        * `value_path` - JSONPath of the value to use
        * `time_path` - JSONPath to some time value to use - the event creation date is used if this option is missing.
        * `group_by_path` - optional JSONPath to a string value used for grouping events
        * `factor` - additional factor that is multiplied to the resulting quotient - defaults to 1
        * `store_time_at_end` - if `true`, the `time`-argument of the newly created event
          will be set to the `time`-argument of the last received event, otherwise it will be set to the
          middle between the last two events.
    MD

    event_description <<-MD
      Events look like this:

          { "value": -5.72, "time": "2013-02-08 16:33:09 +0100" }
    MD

    def validate_options
      unless options['expected_receive_period_in_days'].present? && options['value_path'].present?
        errors.add(:base, "expected_receive_period_in_days and value_path are required")
      end
    end

    def default_options
      {
        'expected_receive_period_in_days' => "2",
        'group_by_path' => "series",
        'value_path' => "value",
        'time_path' => "time"
      }
    end

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.sort_by { |e| time_for e }.each do |event|
        data = parse event
        compute_difference_quotient data
        remember data
      end
    end

    private

    def group_for(event)
      ((options['group_by_path'].present? && Utils.value_at(event.payload, options['group_by_path'])) || 'no_group')
    end

    def value_for(event)
      Utils.value_at(event.payload, options['value_path']).to_f
    end

    def time_for(event)
      time = if options['time_path'].present? then
        DateTime.parse(Utils.value_at(event.payload, options['time_path']))
      else
        event.created_at
      end
      time.to_time.to_f
    end

    def parse(event)
      {
        'group' => group_for(event),
        'value' => value_for(event),
        'time' => time_for(event)
      }
    end

    def factor
      ((options['factor'].present? && options['factor'].to_f) || 1)
    end

    def compute_difference_quotient data
      if memory['data'] && memory['data'][data['group']]
        old_data = memory['data'][data['group']]
        timediff = data['time'] - old_data['time']
        if timediff != 0
          quotient = (data['value'] - old_data['value']) / timediff
          time = options['store_time_at_end'].to_s == 'true' ? data['time'] : ((old_data['time'] + data['time']) / 2)
          create_event :payload => {"value" => quotient * factor,
                                    "time" => Time.at(time).iso8601.to_s,
                                    "group" => data['group']}
        end
      end
    end

    def remember(data)
      memory['data'] ||= {}
      memory['data'][data['group']] = data
    end
  end
end
