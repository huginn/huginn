module LiquidInterpolatable
  extend ActiveSupport::Concern

  included do
    validate :validate_interpolation
  end

  def valid?(context = nil)
    super
  rescue Liquid::Error
    errors.empty?
  end

  def validate_interpolation
    interpolated
  rescue Liquid::Error => e
    errors.add(:options, "has an error with Liquid templating: #{e.message}")
    false
  end

  def interpolate_options(options, event = {})
    case options
      when String
        interpolate_string(options, event)
      when ActiveSupport::HashWithIndifferentAccess, Hash
        options.inject(ActiveSupport::HashWithIndifferentAccess.new) { |memo, (key, value)| memo[key] = interpolate_options(value, event); memo }
      when Array
        options.map { |value| interpolate_options(value, event) }
      else
        options
    end
  end

  def interpolated(event = {})
    key = [options, event]
    @interpolated_cache ||= {}
    @interpolated_cache[key] ||= interpolate_options(options, event)
    @interpolated_cache[key]
  end

  def interpolate_string(string, event)
    Liquid::Template.parse(string).render!(event.to_liquid, registers: {agent: self})
  end

  require 'uri'
  module Filters
    # Percent encoding for URI conforming to RFC 3986.
    # Ref: http://tools.ietf.org/html/rfc3986#page-12
    def uri_escape(string)
      CGI.escape(string) rescue string
    end

    # Escape a string for use in XPath expression
    def to_xpath(string)
      subs = string.to_s.scan(/\G(?:\A\z|[^"]+|[^']+)/).map { |x|
        case x
        when /"/
          %Q{'#{x}'}
        else
          %Q{"#{x}"}
        end
      }
      if subs.size == 1
        subs.first
      else
        'concat(' << subs.join(', ') << ')'
      end
    end
  end
  Liquid::Template.register_filter(LiquidInterpolatable::Filters)

  module Tags
    class Credential < Liquid::Tag
      def initialize(tag_name, name, tokens)
        super
        @credential_name = name.strip
      end

      def render(context)
        credential = context.registers[:agent].credential(@credential_name)
        raise "No user credential named '#{@credential_name}' defined" if credential.nil?
        credential
      end
    end
  end
  Liquid::Template.register_tag('credential', LiquidInterpolatable::Tags::Credential)
end
