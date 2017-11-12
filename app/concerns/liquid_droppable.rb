# frozen_string_literal: true

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

    def as_json
      return {} unless defined?(self.class::METHODS)
      Hash[self.class::METHODS.map { |m| [m, send(m).as_json]}]
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

  class MatchDataDrop < Drop
    METHODS = %w[pre_match post_match names size]

    METHODS.each { |attr|
      define_method(attr) {
        @object.__send__(attr)
      }
    }

    def to_s
      @object[0]
    end

    def liquid_method_missing(method)
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
    METHODS = URI::Generic::COMPONENT

    METHODS.each { |attr|
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

  class ActiveRecordCollectionDrop < Drop
    include Enumerable

    def each(&block)
      @object.each(&block)
    end

    # required for variable indexing as array
    def [](i)
      case i
      when Integer
        @object[i]
      when 'size', 'first', 'last'
        __send__(i)
      end
    end

    # required for variable indexing as array
    def fetch(i, &block)
      @object.fetch(i, &block)
    end

    # compatibility with array; also required by the `size` filter
    def size
      @object.count
    end

    # compatibility with array
    def first
      @object.first
    end

    # compatibility with array
    def last
      @object.last
    end

    # This drop currently does not support the `slice` filter.
  end

  class ::ActiveRecord::Associations::CollectionProxy
    def to_liquid
      ActiveRecordCollectionDrop.new(self)
    end
  end
end
