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
    const_set :Drop,
              if Kernel.const_defined?(drop_name = "#{name}Drop")
                Kernel.const_get(drop_name)
              else
                Kernel.const_set(drop_name, Class.new(Drop))
              end
  end

  def to_liquid
    self.class::Drop.new(self)
  end

  class MatchDataDrop < Liquid::Drop
    def initialize(object)
      @object = object
    end

    %w[pre_match post_match names size].each { |attr|
      define_method(attr) {
        @object.__send__(attr)
      }
    }

    def to_s
      @object[0]
    end

    def before_method(method)
      @object[method]
    rescue IndexError
      nil
    end
  end

  class ::MatchData
    def to_liquid
      MatchDataDrop.new(self)
    end
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
