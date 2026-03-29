require "dotenv/substitutions/variable"
require "dotenv/substitutions/command" if RUBY_VERSION > "1.8.7"

module Dotenv
  # Error raised when encountering a syntax error while parsing a .env file.
  class FormatError < SyntaxError; end

  # Parses the `.env` file format into key/value pairs.
  # It allows for variable substitutions, command substitutions, and exporting of variables.
  class Parser
    @substitutions = [
      Dotenv::Substitutions::Command,
      Dotenv::Substitutions::Variable
    ]

    LINE = /
      (?:^|\A)                # beginning of line
      \s*                     # leading whitespace
      (?<export>export\s+)?   # optional export
      (?<key>[\w.]+)          # key
      (?:                     # optional separator and value
        (?:\s*=\s*?|:\s+?)    #   separator
        (?<value>             #   optional value begin
          \s*'(?:\\'|[^'])*'  #     single quoted value
          |                   #     or
          \s*"(?:\\"|[^"])*"  #     double quoted value
          |                   #     or
          [^\#\n]+            #     unquoted value
        )?                    #   value end
      )?                      # separator and value end
      \s*                     # trailing whitespace
      (?:\#.*)?               # optional comment
      (?:$|\z)                # end of line
    /x

    QUOTED_STRING = /\A(['"])(.*)\1\z/m

    class << self
      attr_reader :substitutions

      def call(...)
        new(...).call
      end
    end

    def initialize(string, overwrite: false)
      # Convert line breaks to same format
      @string = string.gsub(/\r\n?/, "\n")
      @hash = {}
      @overwrite = overwrite
    end

    def call
      @string.scan(LINE) do
        match = $LAST_MATCH_INFO

        if existing?(match[:key])
          # Use value from already defined variable
          @hash[match[:key]] = ENV[match[:key]]
        elsif match[:export] && !match[:value]
          # Check for exported variable with no value
          if !@hash.member?(match[:key])
            raise FormatError, "Line #{match.to_s.inspect} has an unset variable"
          end
        else
          @hash[match[:key]] = parse_value(match[:value] || "")
        end
      end

      @hash
    end

    private

    # Determine if a variable is already defined and should not be overwritten.
    def existing?(key)
      !@overwrite && key != "DOTENV_LINEBREAK_MODE" && ENV.key?(key)
    end

    def parse_value(value)
      # Remove surrounding quotes
      value = value.strip.sub(QUOTED_STRING, '\2')
      maybe_quote = Regexp.last_match(1)

      # Expand new lines in double quoted values
      value = expand_newlines(value) if maybe_quote == '"'

      # Unescape characters and performs substitutions unless value is single quoted
      if maybe_quote != "'"
        value = unescape_characters(value)
        self.class.substitutions.each { |proc| value = proc.call(value, @hash) }
      end

      value
    end

    def unescape_characters(value)
      value.gsub(/\\([^$])/, '\1')
    end

    def expand_newlines(value)
      if (@hash["DOTENV_LINEBREAK_MODE"] || ENV["DOTENV_LINEBREAK_MODE"]) == "legacy"
        value.gsub('\n', "\n").gsub('\r', "\r")
      else
        value.gsub('\n', "\\\\\\n").gsub('\r', "\\\\\\r")
      end
    end
  end
end
