module SerializeAndNormalize
  extend ActiveSupport::Concern

  module ClassMethods
    def serialize_and_normalize(*column_names)
      column_names.flatten.uniq.compact.map(&:to_sym).each do |column_name|
        setup_name = "setup_#{column_name}".to_sym
        normalize_name = "normalize_#{column_name}".to_sym
        validate_name = "validate_#{column_name}".to_sym

        serialize column_name
        after_initialize setup_name
        before_validation normalize_name
        before_save normalize_name
        validate validate_name

        class_eval <<-RUBY
          def #{setup_name}
            self[:#{column_name}] ||= ActiveSupport::HashWithIndifferentAccess.new
          end

          def #{validate_name}
            # Implement me in your subclass.
          end

          def #{normalize_name}
            self.#{column_name} = self[:#{column_name}]
          end

          def #{column_name}=(data)
            data = (JSON.parse(data) rescue data) if data.is_a?(String)

            case data
              when ActiveSupport::HashWithIndifferentAccess
                self[:#{column_name}] = data
              when Hash
                self[:#{column_name}] = ActiveSupport::HashWithIndifferentAccess.new(data)
              else
                self[:#{column_name}] = data
            end
          end
        RUBY
      end
    end
  end
end
