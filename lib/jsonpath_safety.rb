# Adapted from jsonpath 1.1.5's Dig and Parser under the MIT License:
# Copyright (c) 2017 Joshua Lin & Gergely Brautigam
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require "jsonpath"
require "active_support/core_ext/object/blank"

# Restrict legacy JSONPath evaluation to data and allowlisted methods.
module JsonpathSafety
  METHODS = {
    String => %w[downcase upcase strip length size empty? present? blank?],
    Array => %w[length size empty? present? blank? first last],
    Hash => %w[length size empty? present? blank?],
  }.transform_values { |names| names.to_set.freeze }.freeze

  def self.allowed_method?(context, key)
    METHODS[context.class]&.include?(key)
  end

  # Apply the same allowlist regardless of the gem's allow_send option.
  module Dig
    def dig_one(context, key)
      case context
      when Hash
        member = @options[:use_symbols] ? key.to_sym : key
        return context[member] if context.key?(member)
      when Array
        index = key.is_a?(String) ? Integer(key, 10, exception: false) : Integer(key, exception: false)
        return context[index] if index
      end

      context.__send__(key) if JsonpathSafety.allowed_method?(context, key)
    end

    def yield_if_diggable(context, key)
      if context.is_a?(Hash)
        member = @options[:use_symbols] ? key.to_sym : key
        return yield if context.key?(member) || @options[:default_path_leaf_to_null]
      end

      yield if JsonpathSafety.allowed_method?(context, key)
    end
  end

  # Retain jsonpath 1.1.5's expression syntax and coercion, but resolve every
  # reference through the guarded Dig implementation, including scalar nodes.
  module Parser
    OPERATORS = %w[== != < <= > >= =~ !~ + -].freeze

    def parse_exp(expression)
      expression = expression.sub(/@/, "").gsub(/^\(/, "").gsub(/\)$/, "").tr('"', "'").strip
      expression.scan(/^\[(\d+)\]/) do |match|
        index = Integer(match[0])
        raise ArgumentError, "node is not an array" unless @_current_node.is_a?(Array)
        raise ArgumentError, "array index out of bounds" if @_current_node.size < index

        @_current_node = @_current_node[index]
        expression = expression.gsub(/^\[\d+\]|\[''\]/, "")
      end

      scanner = StringScanner.new(expression)
      keys = []
      operator = operand = nil
      until scanner.eos?
        if (token = scanner.scan(/\['[a-zA-Z@&*\/$%^?_]+'\]|\.[a-zA-Z0-9_]+[?]?/))
          keys << token.gsub(/[\[\]'.]|\s+/, "")
        elsif (token = scanner.scan(/(\s+)?[<>=!\-+][=~]?(\s+)?/))
          operator = token.strip
        else
          operand = parse_operand(scanner.rest, operator)
          scanner.terminate
        end
      end

      value = dig(@_current_node, *keys)
      return !!value if value.nil? || operator.nil?

      raise ArgumentError, "unsupported JSONPath operator" unless OPERATORS.include?(operator)

      value = Float(value) rescue value
      operand = Float(operand) rescue operand
      value.public_send(operator, operand)
    end

    private

    def parse_operand(token, operator)
      case token
      when "true" then true
      when "false" then false
      else
        operator == "=~" ? parse_regex(token) : token.gsub(/^'|'$/, "").strip
      end
    end
  end
end

JsonPath::Dig.prepend(JsonpathSafety::Dig)
JsonPath::Parser.prepend(JsonpathSafety::Parser)
