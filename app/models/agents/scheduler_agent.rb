require 'rufus-scheduler'

module Agents
  class SchedulerAgent < Agent
    cannot_be_scheduled!
    cannot_receive_events!
    cannot_create_events!
    can_run_other_agents!

    description <<-MD
      This agent periodically triggers a run of each target Agent according to a user-defined schedule.

      Select target Agents and set a cron-style schedule to `schedule`.
      In the traditional cron format, a schedule part consists of these five columns: `minute hour day-of-month month day-of-week`.

      * `0 22 * * 1-5`: every day of the week at 22:00 (10pm)

      In this variant, you can also specify seconds:

      * `30 0 22 * * 1-5`: every day of the week at 22:00:30

      And timezones:

      * `0 22 * * 1-5 Europe/Paris`: every day of the week when it's 22:00 in Paris

      * `0 22 * * 1-5 Etc/GMT+2`: every day of the week when it's 22:00 in GMT+2

      There's also a way to specify "last day of month":

      * `0 22 L * *`: every month on the last day at 22:00

      And "monthdays":

      * `0 22 * * sun#1,sun#2`: every first and second sunday of the month, at 22:00

      * `0 22 * * sun#L1`: every last sunday of the month, at 22:00
    MD

    def default_options
      { 'schedule' => '0 * * * *' }
    end

    def working?
      true
    end

    def check!
      targets.active.each { |target|
        log "Agent run queued for '#{target.name}'"
        Agent.async_check(target.id)
      }
    end

    def validate_options
      if (spec = options['schedule']).present?
        begin
          Rufus::Scheduler::CronLine.new(spec)
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
