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
      const_get(:TYPES).map(&:constantize)
    end

    private
    def load_types_in
      module_name = "Agents"
      const_set(:BASE_CLASS_NAME, module_name.singularize)
      const_set(:TYPES, Dir[Rails.root.join("app", "models", module_name.underscore, "*.rb")].map { |path| module_name + "::" + File.basename(path, ".rb").camelize })
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
