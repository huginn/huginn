class UpdateKeepEventsForToBeInSeconds < ActiveRecord::Migration[4.2]
  class Agent < ActiveRecord::Base; end

  SECONDS_IN_DAY = 60 * 60 * 24

  def up
    Agent.update_all ['keep_events_for = keep_events_for * ?', SECONDS_IN_DAY]
  end

  def down
    Agent.update_all ['keep_events_for = keep_events_for / ?', SECONDS_IN_DAY]
  end
end
