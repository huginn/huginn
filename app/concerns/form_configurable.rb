module FormConfigurable
  extend ActiveSupport::Concern

  included do
    class_attribute :_form_configurable_fields
    self._form_configurable_fields = HashWithIndifferentAccess.new { |h,k| h[k] = [] }
  end

  delegate :form_configurable_attributes, to: :class
  delegate :form_configurable_fields, to: :class

  def is_form_configurable?
    true
  end

  def validate_option(method)
    if self.respond_to? "validate_#{method}".to_sym
      self.send("validate_#{method}".to_sym)
    else
      false
    end
  end

  def complete_option(method)
    if self.respond_to? "complete_#{method}".to_sym
      self.send("complete_#{method}".to_sym)
    end
  end

  module ClassMethods
    def form_configurable(name, *args)
      options = args.extract_options!.reverse_merge(roles: [], type: :string)

      if args.all? { |arg| arg.is_a?(Symbol) }
        options.assert_valid_keys([:type, :roles, :values, :ace, :cache_response])
      end

      if options[:type] == :array && (options[:values].blank? || !options[:values].is_a?(Array))
        raise ArgumentError.new('When using :array as :type you need to provide the :values as an Array')
      end

      if options[:roles].is_a?(Symbol)
        options[:roles] = [options[:roles]]
      end

      if options[:type] == :array
        options[:roles] << :completable
        class_eval <<-EOF
          def complete_#{name}
            #{options[:values]}.map { |v| {text: v, id: v} }
          end
        EOF
      end

      _form_configurable_fields[name] = options
    end

    def form_configurable_fields
      self._form_configurable_fields
    end

    def form_configurable_attributes
      form_configurable_fields.keys
    end
  end
end
