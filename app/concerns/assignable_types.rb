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
    errors.add(:type, "is not a valid type") unless self.class.valid_type?(type)
  end

  module ClassMethods
    def load_types_in
      module_name = "Agents"
      const_set(:BASE_CLASS_NAME, module_name.singularize)
      const_set(:TYPES, Dir[Rails.root.join("app", "models", module_name.underscore, "*.rb")].map { |path| module_name + "::" + File.basename(path, ".rb").camelize })
    end

    def types
      const_get(:TYPES).map(&:constantize)
    end

    def valid_type?(type)
      const_get(:TYPES).include?(type)
    end
  end
end
