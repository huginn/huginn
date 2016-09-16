# Encapsulates the logic for an HTML schedule selector.
class ScheduleSelector < Selector
  # data is automatically set to the data source to separate concerns.
  def initialize(data: Agent::SCHEDULES, **args)
    super
  end

  protected

  def choices
    data.map { |schedule| [schedule.humanize.titleize, schedule] }
  end
end
