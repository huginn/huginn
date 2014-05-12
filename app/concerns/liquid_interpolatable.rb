module LiquidInterpolatable
  extend ActiveSupport::Concern

  def interpolate_options(options, payload)
    case options.class.to_s
    when 'String'
      Liquid::Template.parse(options).render(payload)
    when 'ActiveSupport::HashWithIndifferentAccess', 'Hash'
      duped_options = options.dup
      duped_options.each do |key, value|
        duped_options[key] = interpolate_options(value, payload)
      end
    when 'Array'
      options.collect do |value|
        interpolate_options(value, payload)
      end
    end
  end

  def interpolate_string(string, payload)
    Liquid::Template.parse(string).render(payload)
  end

  require 'uri'
  # Percent encoding for URI conforming to RFC 3986.
  # Ref: http://tools.ietf.org/html/rfc3986#page-12
  module Huginn
    def uri_escape(string)
      CGI::escape string
    end
  end

  Liquid::Template.register_filter(LiquidInterpolatable::Huginn)
end
