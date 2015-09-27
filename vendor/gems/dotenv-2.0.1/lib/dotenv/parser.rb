require "dotenv/substitutions/variable"
require "dotenv/substitutions/command" if RUBY_VERSION > "1.8.7"

module Dotenv
  class FormatError < SyntaxError; end

  # This class enables parsing of a string for key value pairs to be returned
  # and stored in the Environment. It allows for variable substitutions and
  # exporting of variables.
  class Parser
    @substitutions =
      Substitutions.constants.map { |const| Substitutions.const_get(const) }

    LINE = /
      \A
      (?:export\s+)?    # optional export
      ([\w\.]+)         # key
      (?:\s*=\s*|:\s+?) # separator
      (                 # optional value begin
        '(?:\'|[^'])*'  #   single quoted value
        |               #   or
        "(?:\"|[^"])*"  #   double quoted value
        |               #   or
        [^#\n]+         #   unquoted value
      )?                # value end
      (?:\s*\#.*)?      # optional comment
      \z
    /x

    class << self
      attr_reader :substitutions

      def call(string)
        new(string).call
      end
    end

    def initialize(string)
      @string = string
      @hash = {}
    end

    def call
      @string.split("\n").each do |line|
        parse_line(line)
      end
      @hash
    end

    private

    def parse_line(line)
      if (match = line.match(LINE))
        key, value = match.captures
        @hash[key] = parse_value(value || "")
      elsif line.split.first == "export"
        if variable_not_set?(line)
          fail FormatError, "Line #{line.inspect} has an unset variable"
        end
      elsif line !~ /\A\s*(?:#.*)?\z/ # not comment or blank line
        fail FormatError, "Line #{line.inspect} doesn't match format"
      end
    end

    def parse_value(value)
      # Remove surrounding quotes
      value = value.strip.sub(/\A(['"])(.*)\1\z/, '\2')

      if Regexp.last_match(1) == '"'
        value = unescape_characters(expand_newlines(value))
      end

      if Regexp.last_match(1) != "'"
        self.class.substitutions.each do |proc|
          value = proc.call(value, @hash)
        end
      end
      value
    end

    def unescape_characters(value)
      value.gsub(/\\([^$])/, '\1')
    end

    def expand_newlines(value)
      value.gsub('\n', "\n")
    end

    def variable_not_set?(line)
      !line.split[1..-1].all? { |var| @hash.member?(var) }
    end
  end
end
