# AgentLogs are temporary records of Agent activity, intended for debugging and error tracking.  They can be viewed
# in Agents' detail pages.  AgentLogs with a `level` of 4 or greater are considered "errors" and automatically update
# Agents' `last_error_log_at` column.  These are often used to determine if an Agent is `working?`.
class AgentLog < ActiveRecord::Base
  attr_accessible :agent, :inbound_event, :level, :message, :outbound_event

  belongs_to :agent
  belongs_to :inbound_event, :class_name => "Event"
  belongs_to :outbound_event, :class_name => "Event"

  validates_presence_of :agent, :message
  validates_numericality_of :level, :only_integer => true, :greater_than_or_equal_to => 0, :less_than => 5

  before_save :truncate_message

  def self.log_for_agent(agent, message, options = {})
    log = agent.logs.create! options.merge(:message => message)
    if agent.logs.count > log_length
      oldest_id_to_keep = agent.logs.limit(1).offset(log_length - 1).pluck("agent_logs.id")
      agent.logs.where("agent_logs.id < ?", oldest_id_to_keep).delete_all
    end

    agent.update_column :last_error_log_at, Time.now if log.level >= 4

    log
  end

  def self.log_length
    ENV['AGENT_LOG_LENGTH'].present? ? ENV['AGENT_LOG_LENGTH'].to_i : 200
  end

  protected

  def truncate_message
    self.message = message[0...2048] if message.present?
  end
end
