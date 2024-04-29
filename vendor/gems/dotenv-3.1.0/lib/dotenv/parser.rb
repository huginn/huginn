require "dotenv/substitutions/variable"
require "dotenv/substitutions/command" if RUBY_VERSION > "1.8.7"

module Dotenv
  # Error raised when encountering a syntax error while parsing a .env file.
  class FormatError < SyntaxError; end

  # Parses the `.env` file format into key/value pairs.
  # It allows for variable substitutions, command substitutions, and exporting of variables.
  class Parser
    @substitutions =
      [Dotenv::Substitutions::Variable, Dotenv::Substitutions::Command]

    LINE = /
      (?:^|\A)              # beginning of line
      \s*                   # leading whitespace
      (?:export\s+)?        # optional export
      ([\w.]+)              # key
      (?:\s*=\s*?|:\s+?)    # separator
      (                     # optional value begin
        \s*'(?:\\'|[^'])*'  #   single quoted value
        |                   #   or
        \s*"(?:\\"|[^"])*"  #   double quoted value
        |                   #   or
        [^\#\r\n]+          #   unquoted value
      )?                    # value end
      \s*                   # trailing whitespace
      (?:\#.*)?             # optional comment
      (?:$|\z)              # end of line
    /x

    class << self
      attr_reader :substitutions

      def call(...)
        new(...).call
      end
    end

    def initialize(string, overwrite: false)
      @string = string
      @hash = {}
      @overwrite = overwrite
    end

    def call
      # Convert line breaks to same format
      lines = @string.gsub(/\r\n?/, "\n")
      # Process matches
      lines.scan(LINE).each do |key, value|
        @hash[key] = parse_value(value || "")
      end
      # Process non-matches
      lines.gsub(LINE, "").split(/[\n\r]+/).each do |line|
        parse_line(line)
      end
      @hash
    end

    private

    def parse_line(line)
      if line.split.first == "export"
        if variable_not_set?(line)
          raise FormatError, "Line #{line.inspect} has an unset variable"
        end
      end
    end

    def parse_value(value)
      # Remove surrounding quotes
      value = value.strip.sub(/\A(['"])(.*)\1\z/m, '\2')
      maybe_quote = Regexp.last_match(1)
      value = unescape_value(value, maybe_quote)
      perform_substitutions(value, maybe_quote)
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

    def variable_not_set?(line)
      !line.split[1..].all? { |var| @hash.member?(var) }
    end

    def unescape_value(value, maybe_quote)
      if maybe_quote == '"'
        unescape_characters(expand_newlines(value))
      elsif maybe_quote.nil?
        unescape_characters(value)
      else
        value
      end
    end

    def perform_substitutions(value, maybe_quote)
      if maybe_quote != "'"
        self.class.substitutions.each do |proc|
          value = proc.call(value, @hash, overwrite: @overwrite)
        end
      end
      value
    end
  end
end
