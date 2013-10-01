module SerializeAndSymbolize
  extend ActiveSupport::Concern

  module ClassMethods
    def serialize_and_symbolize(*column_names)
      column_names.flatten.uniq.compact.map(&:to_sym).each do |column_name|
        setup_name = "setup_#{column_name}".to_sym
        symbolize_name = "symbolize_#{column_name}".to_sym
        validate_name = "validate_#{column_name}".to_sym

        serialize column_name
        after_initialize setup_name
        before_validation symbolize_name
        before_save symbolize_name
        validate validate_name

        class_eval <<-RUBY
          def #{setup_name}
            self[:#{column_name}] ||= {}
          end

          def #{validate_name}
            # Implement me in your subclass.
          end

          def #{symbolize_name}
            self.#{column_name} = self[:#{column_name}]
          end

          def #{column_name}=(data)
            if data.is_a?(String)
              self[:#{column_name}] = JSON.parse(data).recursively_symbolize_keys rescue {}
            elsif data.is_a?(Hash)
              self[:#{column_name}] = data.recursively_symbolize_keys
            else
              self[:#{column_name}] = data
            end
          end
        RUBY
      end
    end
  end
end
