module LiquidDroppable
  extend ActiveSupport::Concern

  class Drop < Liquid::Drop
    def initialize(object)
      @object = object
    end
  end

  included do
    const_set :Drop, Kernel.const_set("#{name}Drop", Class.new(Drop))
  end

  def to_liquid(*args)
    self.class::Drop.new(self, *args)
  end
end
