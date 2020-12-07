require 'ostruct'

# This is a helper class for managing Scenario imports, used by the ScenarioImportsController.  This class behaves much
# like a normal ActiveRecord object, with validations and callbacks.  However, it is never persisted to the database.
class ScenarioImport
  include ActiveModel::Model
  include ActiveModel::Callbacks
  include ActiveModel::Validations::Callbacks

  DANGEROUS_AGENT_TYPES = %w[Agents::ShellCommandAgent]
  URL_REGEX = /\Ahttps?:\/\//i

  attr_accessor :file, :url, :data, :do_import, :merges

  attr_reader :user

  before_validation :parse_file
  before_validation :fetch_url

  validate :validate_presence_of_file_url_or_data
  validates_format_of :url, :with => URL_REGEX, :allow_nil => true, :allow_blank => true, :message => "appears to be invalid"
  validate :validate_data
  validate :generate_diff

  def step_one?
    data.blank?
  end

  def step_two?
    data.present?
  end

  def set_user(user)
    @user = user
  end

  def existing_scenario
    @existing_scenario ||= user.scenarios.find_by(:guid => parsed_data["guid"])
  end

  def dangerous?
    (parsed_data['agents'] || []).any? { |agent| DANGEROUS_AGENT_TYPES.include?(agent['type']) }
  end

  def parsed_data
    @parsed_data ||= (data && JSON.parse(data) rescue {}) || {}
  end

  def agent_diffs
    @agent_diffs || generate_diff
  end

  def import_confirmed?
    do_import == "1"
  end

  def import(options = {})
    success = true
    guid = parsed_data['guid']
    description = parsed_data['description']
    name = parsed_data['name']
    links = parsed_data['links']
    control_links = parsed_data['control_links'] || []
    tag_fg_color = parsed_data['tag_fg_color']
    tag_bg_color = parsed_data['tag_bg_color']
    icon = parsed_data['icon']
    source_url = parsed_data['source_url'].presence || nil
    @scenario = user.scenarios.where(:guid => guid).first_or_initialize
    @scenario.update!(name: name, description: description,
                                 source_url: source_url, public: false,
                                 tag_fg_color: tag_fg_color,
                                 tag_bg_color: tag_bg_color,
                                 icon: icon)

    unless options[:skip_agents]
      created_agents = agent_diffs.map do |agent_diff|
        agent = agent_diff.agent || Agent.build_for_type("Agents::" + agent_diff.type.incoming, user)
        agent.guid = agent_diff.guid.incoming
        agent.attributes = { :name => agent_diff.name.updated,
                             :disabled => agent_diff.disabled.updated, # == "true"
                             :options => agent_diff.options.updated,
                             :scenario_ids => [@scenario.id] }
        agent.schedule = agent_diff.schedule.updated if agent_diff.schedule.present?
        agent.keep_events_for = agent_diff.keep_events_for.updated if agent_diff.keep_events_for.present?
        agent.propagate_immediately = agent_diff.propagate_immediately.updated if agent_diff.propagate_immediately.present? # == "true"
        agent.service_id = agent_diff.service_id.updated if agent_diff.service_id.present?
        unless agent.save
          success = false
          errors.add(:base, "Errors when saving '#{agent_diff.name.incoming}': #{agent.errors.full_messages.to_sentence}")
        end
        agent
      end

      if success
        links.each do |link|
          receiver = created_agents[link['receiver']]
          source = created_agents[link['source']]
          receiver.sources << source unless receiver.sources.include?(source)
        end

        control_links.each do |control_link|
          controller = created_agents[control_link['controller']]
          control_target = created_agents[control_link['control_target']]
          controller.control_targets << control_target unless controller.control_targets.include?(control_target)
        end
      end
    end

    success
  end

  def scenario
    @scenario || @existing_scenario
  end

  protected

  def parse_file
    if data.blank? && file.present?
      self.data = file.read.force_encoding(Encoding::UTF_8)
    end
  end

  def fetch_url
    if data.blank? && url.present? && url =~ URL_REGEX
      self.data = Faraday.get(url).body
    end
  end

  def validate_data
    if data.present?
      @parsed_data = JSON.parse(data) rescue {}
      if (%w[name guid agents] - @parsed_data.keys).length > 0
        errors.add(:base, "The provided data does not appear to be a valid Scenario.")
        self.data = nil
      end
    else
      @parsed_data = nil
    end
  end

  def validate_presence_of_file_url_or_data
    unless file.present? || url.present? || data.present?
      errors.add(:base, "Please provide either a Scenario JSON File or a Public Scenario URL.")
    end
  end

  def generate_diff
    @agent_diffs = (parsed_data['agents'] || []).map.with_index do |agent_data, index|
      # AgentDiff is defined at the end of this file.
      agent_diff = AgentDiff.new(agent_data, parsed_data['schema_version'])
      if existing_scenario
        # If this Agent exists already, update the AgentDiff with the local version's information.
        agent_diff.diff_with! existing_scenario.agents.find_by(:guid => agent_data['guid'])

        begin
          # Update the AgentDiff with any hand-merged changes coming from the UI.  This only happens when this
          # Agent already exists locally and has conflicting changes.
          agent_diff.update_from! merges[index.to_s] if merges
        rescue JSON::ParserError
          errors.add(:base, "Your updated options for '#{agent_data['name']}' were unparsable.")
        end
      end
      if agent_diff.requires_service? && merges.present? && merges[index.to_s].present? && merges[index.to_s]['service_id'].present?
        agent_diff.service_id = AgentDiff::FieldDiff.new(merges[index.to_s]['service_id'].to_i)
      end
      agent_diff
    end
  end

  # AgentDiff is a helper object that encapsulates an incoming Agent.  All fields will be returned as an array
  # of either one or two values.  The first value is the incoming value, the second is the existing value, if
  # it differs from the incoming value.
  class AgentDiff < OpenStruct
    class FieldDiff
      attr_accessor :incoming, :current, :updated

      def initialize(incoming)
        @incoming = incoming
        @updated = incoming
      end

      def set_current(current)
        @current = current
        @requires_merge = (incoming != current)
      end

      def requires_merge?
        @requires_merge
      end
    end

    def initialize(agent_data, schema_version)
      super()
      @schema_version = schema_version
      @requires_merge = false
      self.agent = nil
      store! agent_data
    end

    BASE_FIELDS = %w[name schedule keep_events_for propagate_immediately disabled guid]
    FIELDS_REQUIRING_TRANSLATION = %w[keep_events_for]

    def agent_exists?
      !!agent
    end

    def requires_merge?
      @requires_merge
    end

    def requires_service?
      !!agent_instance.try(:oauthable?)
    end

    def store!(agent_data)
      self.type = FieldDiff.new(agent_data["type"].split("::").pop)
      self.options = FieldDiff.new(agent_data['options'] || {})
      BASE_FIELDS.each do |option|
        if agent_data.has_key?(option)
          value = agent_data[option]
          value = send(:"translate_#{option}", value) if option.in?(FIELDS_REQUIRING_TRANSLATION)
          self[option] = FieldDiff.new(value)
        end
      end
    end

    def translate_keep_events_for(old_value)
      if schema_version < 1
        # Was stored in days, now is stored in seconds.
        old_value.to_i.days
      else
        old_value
      end
    end

    def schema_version
      (@schema_version || 0).to_i
    end

    def diff_with!(agent)
      return unless agent.present?

      self.agent = agent

      type.set_current(agent.short_type)
      options.set_current(agent.options || {})

      @requires_merge ||= type.requires_merge?
      @requires_merge ||= options.requires_merge?

      BASE_FIELDS.each do |field|
        next unless self[field].present?
        self[field].set_current(agent.send(field))

        @requires_merge ||= self[field].requires_merge?
      end
    end

    def update_from!(merges)
      each_field do |field, value, selection_options|
        value.updated = merges[field]
      end

      if options.requires_merge?
        options.updated = JSON.parse(merges['options'])
      end
    end

    def each_field
      boolean = [["True", "true"], ["False", "false"]]
      yield 'name', name if name.requires_merge?
      yield 'schedule', schedule, Agent::SCHEDULES.map {|s| [AgentHelper.builtin_schedule_name(s), s] } if self['schedule'].present? && schedule.requires_merge?
      yield 'keep_events_for', keep_events_for, Agent::EVENT_RETENTION_SCHEDULES if self['keep_events_for'].present? && keep_events_for.requires_merge?
      yield 'propagate_immediately', propagate_immediately, boolean if self['propagate_immediately'].present? && propagate_immediately.requires_merge?
      yield 'disabled', disabled, boolean if disabled.requires_merge?
    end

    def agent_instance
      "Agents::#{self.type.updated}".constantize.new
    end
  end
end
