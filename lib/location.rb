require 'liquid'

Location = Struct.new(:lat, :lng, :radius, :speed, :course)

class Location
  include LiquidDroppable

  protected :[]=

  def initialize(data = {})
    super()

    case data
    when Array
      raise ArgumentError, 'unsupported location data' unless data.size == 2
      self.lat, self.lng = data
    when Hash, Location
      data.each { |key, value|
        case key.to_sym
        when :lat, :latitude
          self.lat = value
        when :lng, :longitude
          self.lng = value
        when :radius
          self.radius = value
        when :speed
          self.speed = value
        when :course
          self.course = value
        end
      }
    else
      raise ArgumentError, 'unsupported location data'
    end

    yield self if block_given?
  end

  def lat=(value)
    self[:lat] = floatify(value) { |f|
      if f.abs <= 90
        f
      else
        raise ArgumentError, 'out of bounds'
      end
    }
  end

  alias latitude  lat
  alias latitude= lat=

  def lng=(value)
    self[:lng] = floatify(value) { |f|
      if f.abs <= 180
        f
      else
        raise ArgumentError, 'out of bounds'
      end
    }
  end

  alias longitude  lng
  alias longitude= lng=

  def radius=(value)
    self[:radius] = floatify(value) { |f| f if f >= 0 }
  end

  def speed=(value)
    self[:speed] = floatify(value) { |f| f if f >= 0 }
  end

  def course=(value)
    self[:course] = floatify(value) { |f| f if (0..360).cover?(f) }
  end

  def present?
    lat && lng
  end

  def empty?
    !present?
  end

  def latlng
    "#{lat},#{lng}"
  end

  private

  def floatify(value)
    case value
    when nil, ''
      return nil
    else
      float = Float(value)
      if block_given?
        yield(float)
      else
        float
      end
    end
  end
end

class LocationDrop
  KEYS = Location.members.map(&:to_s).concat(%w[latitude longitude latlng])

  def liquid_method_missing(key)
    if KEYS.include?(key)
      @object.__send__(key)
    end
  end
end
