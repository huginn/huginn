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
        options.assert_valid_keys([:type, :roles, :values])
      end

      if options[:type] == :array && (options[:values].blank? || !options[:values].is_a?(Array))
        raise ArgumentError.new('When using :array as :type you need to provide the :values as an Array')
      end

      if options[:roles].is_a?(Symbol)
        options[:roles] = [options[:roles]]
      end

      if options[:roles].include?(:completable) && !self.method_defined?("complete_#{name}".to_sym)
        # Not really sure, but method_defined? does not seem to work because we do not have the 'full' Agent class here
        #raise ArgumentError.new("'complete_#{name}' needs to be defined to validate '#{name}'")
      end

      if options[:roles].include?(:validatable) && !self.method_defined?("validate_#{name}".to_sym)
        #raise ArgumentError.new("'validate_#{name}' needs to be defined to validate '#{name}'")
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
