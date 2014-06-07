# This is a helper class for managing Scenario imports.
class ScenarioImport
  include ActiveModel::Model
  include ActiveModel::Callbacks
  include ActiveModel::Validations::Callbacks

  DANGEROUS_AGENT_TYPES = %w[Agents::ShellCommandAgent]
  URL_REGEX = /\Ahttps?:\/\//i

  attr_accessor :file, :url, :data, :do_import

  attr_reader :user

  before_validation :parse_file
  before_validation :fetch_url

  validate :validate_presence_of_file_url_or_data
  validates_format_of :url, :with => URL_REGEX, :allow_nil => true, :allow_blank => true, :message => "appears to be invalid"
  validate :validate_data

  def step_one?
    data.blank?
  end

  def step_two?
    valid?
  end

  def set_user(user)
    @user = user
  end

  def existing_scenario
    @existing_scenario ||= user.scenarios.find_by_guid(parsed_data["guid"])
  end

  def dangerous?
    (parsed_data['agents'] || []).any? { |agent| DANGEROUS_AGENT_TYPES.include?(agent['type']) }
  end

  def parsed_data
    @parsed_data ||= data && JSON.parse(data) rescue {}
  end

  def do_import?
    do_import == "1"
  end

  def import!(options = {})
    guid = parsed_data['guid']
    description = parsed_data['description']
    name = parsed_data['name']
    agents = parsed_data['agents']
    links = parsed_data['links']
    source_url = parsed_data['source_url'].presence || nil
    @scenario = user.scenarios.where(:guid => guid).first_or_initialize
    @scenario.update_attributes!(:name => name, :description => description,
                                 :source_url => source_url, :public => false)

    unless options[:skip_agents]
      created_agents = agents.map do |agent_data|
        agent = @scenario.agents.find_by(:guid => agent_data['guid']) || Agent.build_for_type(agent_data['type'], user)
        agent.guid = agent_data['guid']
        agent.attributes = { :name => agent_data['name'],
                             :schedule => agent_data['schedule'],
                             :keep_events_for => agent_data['keep_events_for'],
                             :propagate_immediately => agent_data['propagate_immediately'],
                             :disabled => agent_data['disabled'],
                             :options => agent_data['options'],
                             :scenario_ids => [@scenario.id] }
        agent.save!
        agent
      end

      links.each do |link|
        receiver = created_agents[link['receiver']]
        source = created_agents[link['source']]
        receiver.sources << source unless receiver.sources.include?(source)
      end
    end
  end

  def scenario
    @scenario || @existing_scenario
  end

  def will_request_local?(url_root)
    data.blank? && file.blank? && url.present? && url.starts_with?(url_root)
  end

  protected

  def parse_file
    if data.blank? && file.present?
      self.data = file.read
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
end