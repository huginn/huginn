module LiquidDroppable
  extend ActiveSupport::Concern

  # In subclasses of this base class, "locals" take precedence over
  # methods.
  class Drop < Liquid::Drop
    class << self
      def inherited(subclass)
        class << subclass
          attr_reader :drop_methods

          # Make all public methods private so that #before_method
          # catches everything.
          def drop_methods!
            return if @drop_methods

            @drop_methods = Set.new

            (public_instance_methods - Drop.public_instance_methods).each { |name|
              @drop_methods << name.to_s
              private name
            }
          end
        end
      end
    end

    def initialize(object, locals = nil)
      self.class.drop_methods!

      @object = object
      @locals = locals || {}
    end

    def before_method(name)
      if @locals.include?(name)
        @locals[name]
      elsif self.class.drop_methods.include?(name)
        __send__(name)
      end
    end

    def each
      return to_enum(__method__) unless block_given?
      self.class.drop_methods.each { |name|
        yield [name, __send__(name)]
      }
    end
  end

  included do
    const_set :Drop, Kernel.const_set("#{name}Drop", Class.new(Drop))
  end

  def to_liquid(*args)
    self.class::Drop.new(self, *args)
  end
end
