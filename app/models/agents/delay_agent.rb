module Agents
  class DelayAgent < Agent

    description <<-MD
      Delay a job until a specified time.

      Either set 'delay' to some integer based unit, (eg 30m, 2h, 1d). Currently only units of minutes or more are supported.
      
      Or set "run_at" to be a parseable date. Run at can also refer to a JSON path from the message.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.
    MD

    event_description <<-MD
      Events are passed through without change, aside from the delay.
    MD

    def validate_options
      unless options['delay'].present? or options['run_at'].present?
         errors.add(:base, "Either 'delay' or 'run_at' options must be set for the delay")
      end
    end

    def default_options
      {
        'delay' => "10m",
        'expected_receive_period_in_days' => "2"
      }
    end

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def delay_to_sec
       m = /([0-9])([dhms])/.match(options['delay'])
       unless (m[2].present?)
          errors.add(:base, "Couldn't understand the delay you want.") and return
       end

       s = m[1].to_i
       if (m[2] == "d")
          s *= 60 * 60 * 24
       elsif (m[2] == "h")
          s *= 60 * 60
       elsif (m[2] == "m")
          s *= 60
       elsif (m[2] == "s")
          s *= 1
       end
       return s
    end

    def receive(incoming_events)
      self.memory[:event_list] ||= []
      incoming_events.each do |event|
        if options['delay'].present?
           now = Time.now
           trigger_time = now + self.delay_to_sec

        elsif options['run_at'].present?
           #either it's a time directly, or it's a json query
           vp = Utils.value_at(event[:payload], options['run_at'])
           vp ||= options['run_at']
           trigger_time = Time.parse(vp, now)

        end

        self.memory[:event_list].push({
           :trigger_time => trigger_time,
           :payload => event[:payload]
        })
      end
    end

    def check
      return unless self.memory[:event_list]
      now = Time.now
      actionable = self.memory[:event_list].select { |x| Time.parse(x[:trigger_time]) <= now }
      remaining = self.memory[:event_list].select { |x| Time.parse(x[:trigger_time]) > now }
      actionable.each do |ev|
         create_event :payload => ev[:payload]
      end
      self.memory['event_list'] = remaining
    end
  end
end
