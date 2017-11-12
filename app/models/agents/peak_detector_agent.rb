require 'pp'

module Agents
  class PeakDetectorAgent < Agent
    cannot_be_scheduled!

    DEFAULT_SEARCH_URL = 'https://twitter.com/search?q={q}'

    description <<-MD
      The Peak Detector Agent will watch for peaks in an event stream.  When a peak is detected, the resulting Event will have a payload message of `message`.  You can include extractions in the message, for example: `I saw a bar of: {{foo.bar}}`, have a look at the [Wiki](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) for details.

      The `value_path` value is a [JSONPath](http://goessner.net/articles/JsonPath/) to the value of interest.  `group_by_path` is a JSONPath that will be used to group values, if present.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.

      You may set `window_duration_in_days` to change the default memory window length of `14` days, `min_peak_spacing_in_days` to change the default minimum peak spacing of `2` days (peaks closer together will be ignored), and `std_multiple` to change the default standard deviation threshold multiple of `3`.

      You may set `min_events` for the minimal number of accumulated events before the agent starts detecting.

      You may set `search_url` to point to something else than Twitter search, using the URI Template syntax defined in [RFC 6570](https://tools.ietf.org/html/rfc6570). Default value is `#{DEFAULT_SEARCH_URL}` where `{q}` will be replaced with group name.
    MD

    event_description <<-MD
      Events look like:

          {
            "message": "Your message",
            "peak": 6,
            "peak_time": 3456789242,
            "grouped_by": "something"
          }
    MD

    def validate_options
      unless options['expected_receive_period_in_days'].present? && options['message'].present? && options['value_path'].present? && options['min_events'].present?
        errors.add(:base, "expected_receive_period_in_days, value_path, min_events and message are required")
      end
      begin
        tmpl = search_url
      rescue => e
        errors.add(:base, "search_url must be a valid URI template: #{e.message}")
      else
        unless tmpl.keys.include?('q')
          errors.add(:base, "search_url must include a variable named 'q'")
        end
      end
    end

    def default_options
      {
        'expected_receive_period_in_days' => "2",
        'group_by_path' => "filter",
        'value_path' => "count",
        'message' => "A peak of {{count}} was found in {{filter}}",
        'min_events' => '4',
      }
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.sort_by(&:created_at).each do |event|
        group = group_for(event)
        remember group, event
        check_for_peak group, event
      end
    end

    def search_url
      Addressable::Template.new(options[:search_url].presence || DEFAULT_SEARCH_URL)
    end

    private

    def check_for_peak(group, event)
      memory['peaks'] ||= {}
      memory['peaks'][group] ||= []

      return if memory['data'][group].length <= options['min_events'].to_i

      if memory['peaks'][group].empty? || memory['peaks'][group].last < event.created_at.to_i - peak_spacing
        average_value, standard_deviation = stats_for(group, :skip_last => 1)
        newest_value, newest_time = memory['data'][group][-1].map(&:to_f)

        if newest_value > average_value + std_multiple * standard_deviation
          memory['peaks'][group] << newest_time
          memory['peaks'][group].reject! { |p| p <= newest_time - window_duration }
          create_event :payload => { 'message' => interpolated(event)['message'], 'peak' => newest_value, 'peak_time' => newest_time, 'grouped_by' => group.to_s }
        end
      end
    end

    def stats_for(group, options = {})
      data = memory['data'][group].map { |d| d.first.to_f }
      data = data[0...(data.length - (options[:skip_last] || 0))]
      length = data.length.to_f
      mean = 0
      mean_variance = 0
      data.each do |value|
        mean += value
      end
      mean /= length
      data.each do |value|
        variance = (value - mean)**2
        mean_variance += variance
      end
      mean_variance /= length
      standard_deviation = Math.sqrt(mean_variance)
      [mean, standard_deviation]
    end

    def window_duration
      if interpolated['window_duration'].present? # The older option
        interpolated['window_duration'].to_i
      else
        (interpolated['window_duration_in_days'] || 14).to_f.days
      end
    end

    def std_multiple
      (interpolated['std_multiple'] || 3).to_f
    end

    def peak_spacing
      if interpolated['peak_spacing'].present? # The older option
        interpolated['peak_spacing'].to_i
      else
        (interpolated['min_peak_spacing_in_days'] || 2).to_f.days
      end
    end

    def group_for(event)
      ((interpolated['group_by_path'].present? && Utils.value_at(event.payload, interpolated['group_by_path'])) || 'no_group')
    end

    def remember(group, event)
      memory['data'] ||= {}
      memory['data'][group] ||= []
      memory['data'][group] << [ Utils.value_at(event.payload, interpolated['value_path']).to_f, event.created_at.to_i ]
      cleanup group
    end

    def cleanup(group)
      newest_time = memory['data'][group].last.last
      memory['data'][group].reject! { |value, time| time <= newest_time - window_duration }
    end
  end
end
