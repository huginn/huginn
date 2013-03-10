require 'pp'

module Agents
  class PeakDetectorAgent < Agent
    cannot_be_scheduled!

    description <<-MD
      Use a PeakDetectorAgent to watch for peaks in an event stream.  When a peak is detected, the resulting Event will have a payload message of `message`.  You can include extractions in the message, for example: `I saw a bar of: <foo.bar>`

      The `value_path` value is a hash path to the value of interest.  `group_by_path` is a hash path that will be used to group values, if present.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.

      You may set `window_duration` to change the default memory window length of two weeks,
      `peak_spacing` to change the default minimum peak spacing of two days, and
      `std_multiple` to change the default standard deviation threshold multiple of 3.
    MD

    event_description <<-MD
      Events look like this:

          { :message => "Your message", :peak => 6, :peak_time => 3456789242, :grouped_by => "something" }
    MD

    def validate_options
      unless options[:expected_receive_period_in_days].present? && options[:message].present? && options[:value_path].present?
        errors.add(:base, "expected_receive_period_in_days, value_path, and message are required")
      end
    end

    def default_options
      {
          :expected_receive_period_in_days => "2",
          :group_by_path => "filter",
          :value_path => "count",
          :message => "A peak was found"
      }
    end

    def working?
      last_receive_at && last_receive_at > options[:expected_receive_period_in_days].to_i.days.ago
    end

    def receive(incoming_events)
      incoming_events.sort_by(&:created_at).each do |event|
        group = group_for(event)
        remember group, event
        check_for_peak group, event
      end
    end

    private

    def check_for_peak(group, event)
      memory[:peaks] ||= {}
      memory[:peaks][group] ||= []

      if memory[:data][group].length > 4 && (memory[:peaks][group].empty? || memory[:peaks][group].last < event.created_at.to_i - peak_spacing)
        average_value, standard_deviation = stats_for(group, :skip_last => 2)
        newest_value = memory[:data][group][-1].first.to_f
        second_newest_value, second_newest_time = memory[:data][group][-2].map(&:to_f)

        #pp({:newest_value => newest_value,
        #    :second_newest_value => second_newest_value,
        #    :average_value => average_value,
        #    :standard_deviation => standard_deviation,
        #    :threshold => average_value + std_multiple * standard_deviation })

        if newest_value < second_newest_value && second_newest_value > average_value + std_multiple * standard_deviation
          memory[:peaks][group] << second_newest_time
          memory[:peaks][group].reject! { |p| p <= second_newest_time - window_duration }
          create_event :payload => { :message => options[:message], :peak => second_newest_value, :peak_time => second_newest_time, :grouped_by => group.to_s }
        end
      end
    end

    def stats_for(group, options = {})
      data = memory[:data][group].map {|d| d.first.to_f }
      data = data[0...(memory[:data][group].length - (options[:skip_last] || 0))]
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
      (options[:window_duration].present? && options[:window_duration].to_i) || 2.weeks
    end

    def std_multiple
      (options[:std_multiple].present? && options[:std_multiple].to_i) || 3
    end

    def peak_spacing
      (options[:peak_spacing].present? && options[:peak_spacing].to_i) || 2.days
    end

    def group_for(event)
      ((options[:group_by_path].present? && value_at(event.payload, options[:group_by_path])) || 'no_group').to_sym
    end

    def remember(group, event)
      memory[:data] ||= {}
      memory[:data][group] ||= []
      memory[:data][group] << [value_at(event.payload, options[:value_path]), event.created_at.to_i]
      cleanup group
    end

    def cleanup(group)
      newest_time = memory[:data][group].last.last
      memory[:data][group].reject! { |value, time| time <= newest_time - window_duration }
    end
  end
end