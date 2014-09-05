# Include this mix-in to make a class droppable to Liquid, and adjust
# its behavior in Liquid by implementing its dedicated Drop class
# named with a "Drop" suffix.
module LiquidDroppable
  extend ActiveSupport::Concern

  class Drop < Liquid::Drop
    def initialize(object)
      @object = object
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
end
