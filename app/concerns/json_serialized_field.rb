require "json_with_indifferent_access"

module JsonSerializedField
  extend ActiveSupport::Concern

  included do
    class_attribute :json_serialized_fields, instance_writer: false, default: []
    class_attribute :json_serialized_field_methods_defined, instance_writer: false, default: []
  end

  class NativeType < ActiveRecord::Type::Json
    def cast(value)
      convert(value) { |json| JSON.parse(json) }
    end

    def deserialize(value)
      convert(super)
    end

    def serialize(value)
      super(convert(value))
    end

    def changed_in_place?(raw_old_value, new_value)
      deserialize(raw_old_value) != cast(new_value)
    end

    private

    def convert(value)
      case value
      when nil
        ActiveSupport::HashWithIndifferentAccess.new
      when ActiveSupport::HashWithIndifferentAccess
        value
      when Hash
        ActiveSupport::HashWithIndifferentAccess.new(value)
      when String
        stripped = value.strip
        return ActiveSupport::HashWithIndifferentAccess.new if stripped.empty?

        parsed = block_given? ? yield(stripped) : JSON.parse(stripped)
        ActiveSupport::HashWithIndifferentAccess.new(parsed)
      else
        value
      end
    rescue JSON::ParserError, TypeError
      value
    end
  end

  module ClassMethods
    def json_serialize(*fields)
      fields.map!(&:to_sym)
      self.json_serialized_fields |= fields

      fields.each do |field|
        configure_json_serialized_field(field)

        next if json_serialized_field_methods_defined.include?(field)

        validate :"#{field}_has_no_errors"

        define_method("#{field}=") do |input|
          instance_variable_set("@#{field}_assignment_error", false)

          value =
            case input
            when String
              if input.strip.empty?
                ActiveSupport::HashWithIndifferentAccess.new
              else
                ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(input))
              end
            when Hash
              ActiveSupport::HashWithIndifferentAccess.new(input)
            else
              instance_variable_set("@#{field}_assignment_error", "cannot be set to an instance of #{input.class}")
              return
            end

          write_attribute(field, value)
        rescue JSON::ParserError, TypeError
          instance_variable_set("@#{field}_assignment_error", "was assigned invalid JSON")
        end

        define_method("#{field}_has_no_errors") do
          if (error = instance_variable_get("@#{field}_assignment_error"))
            errors.add(field, error)
          end
        end

        self.json_serialized_field_methods_defined += [field]
      end
    end

    def reset_column_information
      super.tap do
        json_serialized_fields.each do |field|
          configure_json_serialized_field(field)
        end
      end
    end

    private

    def configure_json_serialized_field(field)
      if native_json_column?(field)
        attribute field, NativeType.new
      else
        serialize field, coder: JsonWithIndifferentAccess
      end
    end

    def native_json_column?(field)
      type = columns_hash[field.to_s]&.type
      [:json, :jsonb].include?(type)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
      false
    end
  end
end
