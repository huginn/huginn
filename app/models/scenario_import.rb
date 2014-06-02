# This is a helper class for managing Scenario imports.
class ScenarioImport
  include ActiveModel::Model
  include ActiveModel::Callbacks
  include ActiveModel::Validations::Callbacks

  URL_REGEX = /\Ahttps?:\/\//i

  attr_accessor :file, :url, :data, :do_import

  attr_reader :user

  before_validation :fetch_url
  before_validation :parse_file

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

  def parsed_data
    @parsed_data
  end

  def do_import?
    do_import == "1"
  end

  def import!
  end

  def scenario
    existing_scenario
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
      if (%w[name guid] - @parsed_data.keys).length > 0
        errors.add(:base, "The provided data does not appear to be a valid Scenario.")
        self.data = nil
      end
    end
  end

  def validate_presence_of_file_url_or_data
    unless file.present? || url.present? || data.present?
      errors.add(:base, "Please provide either a Scenario JSON File or a Public Scenario URL.")
    end
  end
end