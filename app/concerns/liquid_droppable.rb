# Include this mix-in to make a class droppable to Liquid, and adjust
# its behavior in Liquid by implementing its dedicated Drop class
# named with a "Drop" suffix.
module LiquidDroppable
  extend ActiveSupport::Concern

  class Drop < Liquid::Drop
    def initialize(object)
      @object = object
    end

    def to_s
      @object.to_s
    end

    def each
      (public_instance_methods - Drop.public_instance_methods).each { |name|
        yield [name, __send__(name)]
      }
    end
  end

  included do
    const_set :Drop, Kernel.const_set("#{name}Drop", Class.new(Drop))
  end

  def to_liquid
    self.class::Drop.new(self)
  end

  require 'uri'

  class URIDrop < Drop
    URI::Generic::COMPONENT.each { |attr|
      define_method(attr) {
        @object.__send__(attr)
      }
    }
  end

  class ::URI::Generic
    def to_liquid
      URIDrop.new(self)
    end
  end
end
