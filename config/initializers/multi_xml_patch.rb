# Same vulnerability as CVE-2013-0156
#   https://groups.google.com/forum/#!topic/rubyonrails-security/61bkgvnSGTQ/discussion

# Code has been submitted back to the project:
#   https://github.com/sferik/multi_xml/pull/34

# Until the fix is released, use this monkey-patch.

require "multi_xml"

module MultiXml
  class DisallowedTypeError < StandardError
    def initialize(type)
      super "Disallowed type attribute: #{type.inspect}"
    end
  end

  DISALLOWED_XML_TYPES = %w(symbol yaml) unless defined?(DISALLOWED_XML_TYPES)

  class << self
    def parse(xml, options={})
      xml ||= ''

      xml.strip! if xml.respond_to?(:strip!)
      begin
        xml = StringIO.new(xml) unless xml.respond_to?(:read)

        char = xml.getc
        return {} if char.nil?
        xml.ungetc(char)

        hash = typecast_xml_value(undasherize_keys(parser.parse(xml)), options[:disallowed_types]) || {}
      rescue DisallowedTypeError
        raise
      rescue parser.parse_error => error
        raise ParseError, error.to_s, error.backtrace
      end
      hash = symbolize_keys(hash) if options[:symbolize_keys]
      hash
    end

    private

    def typecast_xml_value(value, disallowed_types=nil)
      disallowed_types ||= DISALLOWED_XML_TYPES

      case value
      when Hash
        if value.include?('type') && !value['type'].is_a?(Hash) && disallowed_types.include?(value['type'])
          raise DisallowedTypeError, value['type']
        end

        if value['type'] == 'array'

          # this commented-out suggestion helps to avoid the multiple attribute
          # problem, but it breaks when there is only one item in the array.
          #
          # from: https://github.com/jnunemaker/httparty/issues/102
          #
          # _, entries = value.detect { |k, v| k != 'type' && v.is_a?(Array) }

          # This attempt fails to consider the order that the detect method
          # retrieves the entries.
          #_, entries = value.detect {|key, _| key != 'type'}

          # This approach ignores attribute entries that are not convertable
          # to an Array which allows attributes to be ignored.
          _, entries = value.detect {|k, v| k != 'type' && (v.is_a?(Array) || v.is_a?(Hash)) }

          if entries.nil? || (entries.is_a?(String) && entries.strip.empty?)
            []
          else
            case entries
            when Array
              entries.map {|entry| typecast_xml_value(entry, disallowed_types)}
            when Hash
              [typecast_xml_value(entries, disallowed_types)]
            else
              raise "can't typecast #{entries.class.name}: #{entries.inspect}"
            end
          end
        elsif value.has_key?(CONTENT_ROOT)
          content = value[CONTENT_ROOT]
          if block = PARSING[value['type']]
            if block.arity == 1
              value.delete('type') if PARSING[value['type']]
              if value.keys.size > 1
                value[CONTENT_ROOT] = block.call(content)
                value
              else
                block.call(content)
              end
            else
              block.call(content, value)
            end
          else
            value.keys.size > 1 ? value : content
          end
        elsif value['type'] == 'string' && value['nil'] != 'true'
          ''
        # blank or nil parsed values are represented by nil
        elsif value.empty? || value['nil'] == 'true'
          nil
        # If the type is the only element which makes it then
        # this still makes the value nil, except if type is
        # a XML node(where type['value'] is a Hash)
        elsif value['type'] && value.size == 1 && !value['type'].is_a?(Hash)
          nil
        else
          xml_value = value.inject({}) do |hash, (k, v)|
            hash[k] = typecast_xml_value(v, disallowed_types)
            hash
          end

          # Turn {:files => {:file => #<StringIO>} into {:files => #<StringIO>} so it is compatible with
          # how multipart uploaded files from HTML appear
          xml_value['file'].is_a?(StringIO) ? xml_value['file'] : xml_value
        end
      when Array
        value.map!{|i| typecast_xml_value(i, disallowed_types)}
        value.length > 1 ? value : value.first
      when String
        value
      else
        raise "can't typecast #{value.class.name}: #{value.inspect}"
      end
    end
  end
end