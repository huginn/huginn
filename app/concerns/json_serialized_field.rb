require 'json_with_indifferent_access'

module JsonSerializedField
  extend ActiveSupport::Concern

  module ClassMethods
    def json_serialize(*fields)
      fields.each do |field|
        class_eval <<-CODE
          serialize :#{field}, JsonWithIndifferentAccess

          validate :#{field}_has_no_errors

          def #{field}=(input)
            @#{field}_assignment_error = false
            case input
              when String
                if input.strip.length == 0
                  self[:#{field}] = ActiveSupport::HashWithIndifferentAccess.new
                else
                  json = JSON.parse(input) rescue nil
                  if json
                    self[:#{field}] = ActiveSupport::HashWithIndifferentAccess.new(json)
                  else
                    @#{field}_assignment_error = "was assigned invalid JSON"
                  end
                end
              when Hash
                self[:#{field}] = ActiveSupport::HashWithIndifferentAccess.new(input)
              else
                @#{field}_assignment_error = "cannot be set to an instance of \#{input.class}"
            end
          end

          def #{field}_has_no_errors
            errors.add(:#{field}, @#{field}_assignment_error) if @#{field}_assignment_error
          end
        CODE
      end
    end
  end
end
