require 'rufus-scheduler'

module Agents
  class SchedulerAgent < Agent
    include AgentControllerConcern

    cannot_be_scheduled!
    cannot_receive_events!
    cannot_create_events!

    @@second_precision_enabled = ENV['ENABLE_SECOND_PRECISION_SCHEDULE'] == 'true'

    cattr_reader :second_precision_enabled

    description <<-MD
      The Scheduler Agent periodically takes an action on target Agents according to a user-defined schedule.

      # Action types

      Set `action` to one of the action types below:

      * `run`: Target Agents are run at intervals, except for those disabled.

      * `disable`: Target Agents are disabled (if not) at intervals.

      * `enable`: Target Agents are enabled (if not) at intervals.

      # Targets

      Select Agents that you want to run periodically by this SchedulerAgent.

      # Schedule

      Set `schedule` to a schedule specification in the [cron](http://en.wikipedia.org/wiki/Cron) format.
      For example:

      * `0 22 * * 1-5`: every day of the week at 22:00 (10pm)

      * `*/10 8-11 * * *`: every 10 minutes from 8:00 to and not including 12:00

      This variant has several extensions as explained below.

      ## Timezones

      You can optionally specify a timezone (default: `#{Time.zone.name}`) after the day-of-week field.

      * `0 22 * * 1-5 Europe/Paris`: every day of the week when it's 22:00 in Paris

      * `0 22 * * 1-5 Etc/GMT+2`: every day of the week when it's 22:00 in GMT+2

      ## Seconds

      You can optionally specify seconds before the minute field.

      * `*/30 * * * * *`: every 30 seconds

      #{"Only multiples of fifteen are allowed as values for the seconds field, i.e. `*/15`, `*/30`, `15,45` etc." unless second_precision_enabled}

      ## Last day of month

      `L` signifies "last day of month" in `day-of-month`.

      * `0 22 L * *`: every month on the last day at 22:00

      ## Weekday names

      You can use three letter names instead of numbers in the `weekdays` field.

      * `0 22 * * Sat,Sun`: every Saturday and Sunday, at 22:00

      ## Nth weekday of the month

      You can specify "nth weekday of the month" like this.

      * `0 22 * * Sun#1,Sun#2`: every first and second Sunday of the month, at 22:00

      * `0 22 * * Sun#L1`: every last Sunday of the month, at 22:00
    MD

    def default_options
      super.update({
        'schedule' => '0 * * * *',
      })
    end

    def working?
      true
    end

    def validate_options
      if (spec = options['schedule']).present?
        begin
          cron = Rufus::Scheduler::CronLine.new(spec)
          unless second_precision_enabled || (cron.seconds - [0, 15, 30, 45, 60]).empty?
            errors.add(:base, "second precision schedule is not allowed in this service")
          end
        rescue ArgumentError
          errors.add(:base, "invalid schedule")
        end
      else
        errors.add(:base, "schedule is missing")
      end
    end

    before_save do
      self.memory.delete('scheduled_at') if self.options_changed?
    end
  end
end
