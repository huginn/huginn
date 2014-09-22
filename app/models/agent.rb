require 'utils'

# Agent is the core class in Huginn, representing a configurable, schedulable, reactive system with memory that can
# be sub-classed for many different purposes.  Agents can emit Events, as well as receive them and react in many different ways.
# The basic Agent API is detailed on the Huginn wiki: https://github.com/cantino/huginn/wiki/Creating-a-new-agent
class Agent < ActiveRecord::Base
  include AssignableTypes
  include MarkdownClassAttributes
  include JSONSerializedField
  include RDBMSFunctions
  include WorkingHelpers
  include LiquidInterpolatable
  include HasGuid
  include LiquidDroppable

  markdown_class_attributes :description, :event_description

  load_types_in "Agents"

  SCHEDULES = %w[every_1m every_2m every_5m every_10m every_30m every_1h every_2h every_5h every_12h every_1d every_2d every_7d
                 midnight 1am 2am 3am 4am 5am 6am 7am 8am 9am 10am 11am noon 1pm 2pm 3pm 4pm 5pm 6pm 7pm 8pm 9pm 10pm 11pm never]

  EVENT_RETENTION_SCHEDULES = [["Forever", 0], ["1 day", 1], *([2, 3, 4, 5, 7, 14, 21, 30, 45, 90, 180, 365].map {|n| ["#{n} days", n] })]

  attr_accessible :options, :memory, :name, :type, :schedule, :controller_ids, :control_target_ids, :disabled, :source_ids, :scenario_ids, :keep_events_for, :propagate_immediately, :drop_pending_events

  json_serialize :options, :memory

  validates_presence_of :name, :user
  validates_inclusion_of :keep_events_for, :in => EVENT_RETENTION_SCHEDULES.map(&:last)
  validate :sources_are_owned
  validate :controllers_are_owned
  validate :control_targets_are_owned
  validate :scenarios_are_owned
  validate :validate_schedule
  validate :validate_options

  after_initialize :set_default_schedule
  before_validation :set_default_schedule
  before_validation :unschedule_if_cannot_schedule
  before_save :unschedule_if_cannot_schedule
  before_create :set_last_checked_event_id
  after_save :possibly_update_event_expirations

  belongs_to :user, :inverse_of => :agents
  belongs_to :service, :inverse_of => :agents
  has_many :events, -> { order("events.id desc") }, :dependent => :delete_all, :inverse_of => :agent
  has_one  :most_recent_event, :inverse_of => :agent, :class_name => "Event", :order => "events.id desc"
  has_many :logs,  -> { order("agent_logs.id desc") }, :dependent => :delete_all, :inverse_of => :agent, :class_name => "AgentLog"
  has_many :received_events, -> { order("events.id desc") }, :through => :sources, :class_name => "Event", :source => :events
  has_many :links_as_source, :dependent => :delete_all, :foreign_key => "source_id", :class_name => "Link", :inverse_of => :source
  has_many :links_as_receiver, :dependent => :delete_all, :foreign_key => "receiver_id", :class_name => "Link", :inverse_of => :receiver
  has_many :sources, :through => :links_as_receiver, :class_name => "Agent", :inverse_of => :receivers
  has_many :receivers, :through => :links_as_source, :class_name => "Agent", :inverse_of => :sources
  has_many :control_links_as_controller, dependent: :delete_all, foreign_key: 'controller_id', class_name: 'ControlLink', inverse_of: :controller
  has_many :control_links_as_control_target, dependent: :delete_all, foreign_key: 'control_target_id', class_name: 'ControlLink', inverse_of: :control_target
  has_many :controllers, through: :control_links_as_control_target, class_name: "Agent", inverse_of: :control_targets
  has_many :control_targets, through: :control_links_as_controller, class_name: "Agent", inverse_of: :controllers
  has_many :scenario_memberships, :dependent => :destroy, :inverse_of => :agent
  has_many :scenarios, :through => :scenario_memberships, :inverse_of => :agents

  scope :active, -> { where(disabled: false) }

  scope :of_type, lambda { |type|
    type = case type
             when Agent
               type.class.to_s
             else
               type.to_s
           end
    where(:type => type)
  }

  def short_type
    type.demodulize
  end

  def check
    # Implement me in your subclass of Agent.
  end

  def default_options
    # Implement me in your subclass of Agent.
    {}
  end

  def receive(events)
    # Implement me in your subclass of Agent.
  end

  def receive_web_request(params, method, format)
    # Implement me in your subclass of Agent.
    ["not implemented", 404]
  end

  # Implement me in your subclass to decide if your Agent is working.
  def working?
    raise "Implement me in your subclass"
  end

  def create_event(attrs)
    if can_create_events?
      events.create!({
         :user => user,
         :expires_at => new_event_expiration_date
      }.merge(attrs))
    else
      error "This Agent cannot create events!"
    end
  end

  def credential(name)
    @credential_cache ||= {}
    if @credential_cache.has_key?(name)
      @credential_cache[name]
    else
      @credential_cache[name] = user.user_credentials.where(:credential_name => name).first.try(:credential_value)
    end
  end

  def reload
    @credential_cache = {}
    super
  end

  def new_event_expiration_date
    keep_events_for > 0 ? keep_events_for.days.from_now : nil
  end

  def update_event_expirations!
    if keep_events_for == 0
      events.update_all :expires_at => nil
    else
      events.update_all "expires_at = " + rdbms_date_add("created_at", "DAY", keep_events_for.to_i)
    end
  end

  def trigger_web_request(params, method, format)
    if respond_to?(:receive_webhook)
      Rails.logger.warn "DEPRECATED: The .receive_webhook method is deprecated, please switch your Agent to use .receive_web_request."
      receive_webhook(params).tap do
        self.last_web_request_at = Time.now
        save!
      end
    else
      receive_web_request(params, method, format).tap do
        self.last_web_request_at = Time.now
        save!
      end
    end
  end

  def unavailable?
    disabled? || dependencies_missing?
  end

  def dependencies_missing?
    self.class.dependencies_missing?
  end

  def default_schedule
    self.class.default_schedule
  end

  def cannot_be_scheduled?
    self.class.cannot_be_scheduled?
  end

  def can_be_scheduled?
    !cannot_be_scheduled?
  end

  def cannot_receive_events?
    self.class.cannot_receive_events?
  end

  def can_receive_events?
    !cannot_receive_events?
  end

  def cannot_create_events?
    self.class.cannot_create_events?
  end

  def can_create_events?
    !cannot_create_events?
  end

  def can_control_other_agents?
    self.class.can_control_other_agents?
  end

  def log(message, options = {})
    puts "Agent##{id}: #{message}" unless Rails.env.test?
    AgentLog.log_for_agent(self, message, options)
  end

  def error(message, options = {})
    log(message, options.merge(:level => 4))
  end

  def delete_logs!
    logs.delete_all
    update_column :last_error_log_at, nil
  end

  def drop_pending_events
    false
  end

  def drop_pending_events=(bool)
    set_last_checked_event_id if bool
  end

  # Callbacks

  def set_default_schedule
    self.schedule = default_schedule unless schedule.present? || cannot_be_scheduled?
  end

  def unschedule_if_cannot_schedule
    self.schedule = nil if cannot_be_scheduled?
  end

  def set_last_checked_event_id
    if can_receive_events? && newest_event_id = Event.maximum(:id)
      self.last_checked_event_id = newest_event_id
    end
  end

  def possibly_update_event_expirations
    update_event_expirations! if keep_events_for_changed?
  end
  
  #Validation Methods
  
  private
  
  def sources_are_owned
    errors.add(:sources, "must be owned by you") unless sources.all? {|s| s.user_id == user_id }
  end
  
  def controllers_are_owned
    errors.add(:controllers, "must be owned by you") unless controllers.all? {|s| s.user_id == user_id }
  end

  def control_targets_are_owned
    errors.add(:control_targets, "must be owned by you") unless control_targets.all? {|s| s.user_id == user_id }
  end

  def scenarios_are_owned
    errors.add(:scenarios, "must be owned by you") unless scenarios.all? {|s| s.user_id == user_id }
  end

  def validate_schedule
    unless cannot_be_scheduled?
      errors.add(:schedule, "is not a valid schedule") unless SCHEDULES.include?(schedule.to_s)
    end
  end
  
  def validate_options
    # Implement me in your subclass to test for valid options.
  end

  # Utility Methods

  def boolify(option_value)
    case option_value
    when true, 'true'
      true
    when false, 'false'
      false
    else
      nil
    end
  end

  # Class Methods

  class << self
    def build_clone(original)
      new(original.slice(:type, :options, :schedule, :controller_ids, :control_target_ids,
                         :source_ids, :keep_events_for, :propagate_immediately)) { |clone|
        # Give it a unique name
        2.upto(count) do |i|
          name = '%s (%d)' % [original.name, i]
          unless exists?(name: name)
            clone.name = name
            break
          end
        end
      }
    end

    def cannot_be_scheduled!
      @cannot_be_scheduled = true
    end

    def cannot_be_scheduled?
      !!@cannot_be_scheduled
    end

    def default_schedule(schedule = nil)
      @default_schedule = schedule unless schedule.nil?
      @default_schedule
    end

    def cannot_create_events!
      @cannot_create_events = true
    end

    def cannot_create_events?
      !!@cannot_create_events
    end

    def cannot_receive_events!
      @cannot_receive_events = true
    end

    def cannot_receive_events?
      !!@cannot_receive_events
    end

    def can_control_other_agents?
      include? AgentControllerConcern
    end

    def gem_dependency_check
      @gem_dependencies_checked = true
      @gem_dependencies_met = yield
    end

    def dependencies_missing?
      @gem_dependencies_checked && !@gem_dependencies_met
    end

    # Find all Agents that have received Events since the last execution of this method.  Update those Agents with
    # their new `last_checked_event_id` and queue each of the Agents to be called with #receive using `async_receive`.
    # This is called by bin/schedule.rb periodically.
    def receive!(options={})
      Agent.transaction do
        scope = Agent.
                select("agents.id AS receiver_agent_id, sources.id AS source_agent_id, events.id AS event_id").
                joins("JOIN links ON (links.receiver_id = agents.id)").
                joins("JOIN agents AS sources ON (links.source_id = sources.id)").
                joins("JOIN events ON (events.agent_id = sources.id AND events.id > links.event_id_at_creation)").
                where("NOT agents.disabled AND (agents.last_checked_event_id IS NULL OR events.id > agents.last_checked_event_id)")
        if options[:only_receivers].present?
          scope = scope.where("agents.id in (?)", options[:only_receivers])
        end

        sql = scope.to_sql()

        agents_to_events = {}
        Agent.connection.select_rows(sql).each do |receiver_agent_id, source_agent_id, event_id|
          agents_to_events[receiver_agent_id.to_i] ||= []
          agents_to_events[receiver_agent_id.to_i] << event_id
        end

        event_ids = agents_to_events.values.flatten.uniq.compact

        Agent.where(:id => agents_to_events.keys).each do |agent|
          agent.update_attribute :last_checked_event_id, event_ids.max
          Agent.async_receive(agent.id, agents_to_events[agent.id].uniq)
        end

        {
          :agent_count => agents_to_events.keys.length,
          :event_count => event_ids.length
        }
      end
    end

    # Given an Agent id and an array of Event ids, load the Agent, call #receive on it with the Event objects, and then
    # save it with an updated `last_receive_at` timestamp.
    #
    # This method is tagged with `handle_asynchronously` and will be delayed and run with delayed_job.  It accepts Agent
    # and Event ids instead of a literal ActiveRecord models because it is preferable to serialize delayed_jobs with ids.
    def async_receive(agent_id, event_ids)
      agent = Agent.find(agent_id)
      begin
        return if agent.unavailable?
        agent.receive(Event.where(:id => event_ids))
        agent.last_receive_at = Time.now
        agent.save!
      rescue => e
        agent.error "Exception during receive: #{e.message} -- #{e.backtrace}"
        raise
      end
    end
    handle_asynchronously :async_receive

    # Given a schedule name, run `check` via `bulk_check` on all Agents with that schedule.
    # This is called by bin/schedule.rb for each schedule in `SCHEDULES`.
    def run_schedule(schedule)
      return if schedule == 'never'
      types = where(:schedule => schedule).group(:type).pluck(:type)
      types.each do |type|
        type.constantize.bulk_check(schedule)
      end
    end

    # Schedule `async_check`s for every Agent on the given schedule.  This is normally called by `run_schedule` once
    # per type of agent, so you can override this to define custom bulk check behavior for your custom Agent type.
    def bulk_check(schedule)
      raise "Call #bulk_check on the appropriate subclass of Agent" if self == Agent
      where("agents.schedule = ? and disabled = false", schedule).pluck("agents.id").each do |agent_id|
        async_check(agent_id)
      end
    end

    # Given an Agent id, load the Agent, call #check on it, and then save it with an updated `last_check_at` timestamp.
    #
    # This method is tagged with `handle_asynchronously` and will be delayed and run with delayed_job.  It accepts an Agent
    # id instead of a literal Agent because it is preferable to serialize delayed_jobs with ids, instead of with the full
    # Agents.
    def async_check(agent_id)
      agent = Agent.find(agent_id)
      begin
        return if agent.unavailable?
        agent.check
        agent.last_check_at = Time.now
        agent.save!
      rescue => e
        agent.error "Exception during check: #{e.message} -- #{e.backtrace}"
        raise
      end
    end
    handle_asynchronously :async_check
  end
end

class AgentDrop
  def type
    @object.short_type
  end

  [
    :name,
    :type,
    :options,
    :memory,
    :sources,
    :receivers,
    :schedule,
    :controllers,
    :control_targets,
    :disabled,
    :keep_events_for,
    :propagate_immediately,
  ].each { |attr|
    define_method(attr) {
      @object.__send__(attr)
    } unless method_defined?(attr)
  }
end
