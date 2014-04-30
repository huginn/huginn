module LiquidInterpolatable
  extend ActiveSupport::Concern

  def interpolate_options(options, payload)
    duped_options = options.dup.tap do |duped_options|
      duped_options.each_pair do |key, value|
        if value.class == String
          duped_options[key] = Liquid::Template.parse(value).render(payload)
        else
          duped_options[key] = value
        end
      end
    end
    duped_options
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
