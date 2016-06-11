module AssignableTypes
  extend ActiveSupport::Concern

  included do
    validate :validate_type
  end

  def short_type
    @short_type ||= self.class.name.demodulize
  end

  def validate_type
    errors.add(:type, "cannot be changed once an instance has been created") if type_changed? && !new_record?
  end

  module ClassMethods
    @@agents = []

    def types
      @@agents
    end

    private
    def register_agent
      @@agents |= [self]
    end
  end
end
