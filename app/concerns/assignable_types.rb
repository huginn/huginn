module AssignableTypes
  extend ActiveSupport::Concern

  included do
    validate :validate_type
  end

  def short_type
    @short_type ||= type.split("::").pop
  end

  def validate_type
    errors.add(:type, "cannot be changed once an instance has been created") if type_changed? && !new_record?
    errors.add(:type, "is not a valid type") unless valid_type?
  end

  module ClassMethods
    def types
      Agent.descendants
    end
  end

  private
  def valid_type?
    begin
      self.class < Agent
    rescue StandardError
      return false
    end
  end
end
