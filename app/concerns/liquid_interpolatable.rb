# :markup: markdown

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
  rescue
    # Calling `interpolated` without an incoming may naturally fail
    # with various errors when an agent expects one.
  end

  # Return the current interpolation context.  Use this in your Agent
  # class to manipulate interpolation context for user.
  #
  # For example, to provide local variables:
  #
  #     # Create a new scope to define variables in:
  #     interpolation_context.stack {
  #       interpolation_context['_something_'] = 42
  #       # And user can say "{{_something_}}" in their options.
  #       value = interpolated['some_key']
  #     }
  #
  def interpolation_context
    @interpolation_context ||= Context.new(self)
  end

  # Take the given object as "self" in the current interpolation
  # context while running a given block.
  #
  # The most typical use case for this is to evaluate options for each
  # received event like this:
  #
  #     def receive(incoming_events)
  #       incoming_events.each do |event|
  #         interpolate_with(event) do
  #           # Handle each event based on "interpolated" options.
  #         end
  #       end
  #     end
  def interpolate_with(self_object)
    case self_object
    when nil
      yield
    else
      context = interpolation_context
      begin
        context.environments.unshift(self_object.to_liquid)
        yield
      ensure
        context.environments.shift
      end
    end
  end

  def interpolate_options(options, self_object = nil)
    interpolate_with(self_object) do
      case options
      when String
        interpolate_string(options)
      when ActiveSupport::HashWithIndifferentAccess, Hash
        options.each_with_object(ActiveSupport::HashWithIndifferentAccess.new) { |(key, value), memo|
          memo[key] = interpolate_options(value)
        }
      when Array
        options.map { |value| interpolate_options(value) }
      else
        options
      end
    end
  end

  def interpolated(self_object = nil)
    interpolate_with(self_object) do
      (@interpolated_cache ||= {})[[options, interpolation_context]] ||=
        interpolate_options(options)
    end
  end

  def interpolate_string(string, self_object = nil)
    interpolate_with(self_object) do
      Liquid::Template.parse(string).render!(interpolation_context)
    end
  end

  class Context < Liquid::Context
    def initialize(agent)
      super({}, {}, { agent: agent }, true)
    end

    def hash
      [@environments, @scopes, @registers].hash
    end

    def eql?(other)
      other.environments == @environments &&
        other.scopes == @scopes &&
        other.registers == @registers
    end
  end

  require 'uri'
  module Filters
    # Percent encoding for URI conforming to RFC 3986.
    # Ref: http://tools.ietf.org/html/rfc3986#page-12
    def uri_escape(string)
      CGI.escape(string) rescue string
    end

    # Parse an input into a URI object, optionally resolving it
    # against a base URI if given.
    #
    # A URI object will have the following properties: scheme,
    # userinfo, host, port, registry, path, opaque, query, and
    # fragment.
    def to_uri(uri, base_uri = nil)
      if base_uri
        URI(base_uri) + uri.to_s
      else
        URI(uri.to_s)
      end
    rescue URI::Error
      nil
    end

    # Get the destination URL of a given URL by recursively following
    # redirects, up to 5 times in a row.  If a given string is not a
    # valid absolute HTTP URL or in case of too many redirects, the
    # original string is returned.  If any network/protocol error
    # occurs while following redirects, the last URL followed is
    # returned.
    def uri_expand(url, limit = 5)
      case url
      when URI
        uri = url
      else
        url = url.to_s
        begin
          uri = URI(url)
        rescue URI::Error
          return url
        end
      end

      http = Faraday.new do |builder|
        builder.adapter :net_http
        # builder.use FaradayMiddleware::FollowRedirects, limit: limit
        # ...does not handle non-HTTP URLs.
      end

      limit.times do
        begin
          case uri
          when URI::HTTP
            return uri.to_s unless uri.host
            response = http.head(uri)
            case response.status
            when 301, 302, 303, 307
              if location = response['location']
                uri += location
                next
              end
            end
          end
        rescue URI::Error, Faraday::Error, SystemCallError => e
          logger.error "#{e.class} in #{__method__}(#{url.inspect}) [uri=#{uri.to_s.inspect}]: #{e.message}:\n#{e.backtrace.join("\n")}"
        end

        return uri.to_s
      end

      logger.error "Too many rediretions in #{__method__}(#{url.inspect}) [uri=#{uri.to_s.inspect}]"

      url
    end

    # Unescape (basic) HTML entities in a string
    #
    # This currently decodes the following entities only: "&apos;",
    # "&quot;", "&lt;", "&gt;", "&amp;", "&#dd;" and "&#xhh;".
    def unescape(input)
      CGI.unescapeHTML(input) rescue input
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

    def regex_replace(input, regex, replacement = nil)
      input.to_s.gsub(Regexp.new(regex), unescape_replacement(replacement.to_s))
    end

    def regex_replace_first(input, regex, replacement = nil)
      input.to_s.sub(Regexp.new(regex), unescape_replacement(replacement.to_s))
    end

    # Serializes data as JSON
    def json(input)
      JSON.dump(input)
    end

    private

    def logger
      @@logger ||=
        if defined?(Rails)
          Rails.logger
        else
          require 'logger'
          Logger.new(STDERR)
        end
    end

    BACKSLASH = "\\".freeze

    UNESCAPE = {
      "a" => "\a",
      "b" => "\b",
      "e" => "\e",
      "f" => "\f",
      "n" => "\n",
      "r" => "\r",
      "s" => " ",
      "t" => "\t",
      "v" => "\v",
    }

    # Unescape a replacement text for use in the second argument of
    # gsub/sub.  The following escape sequences are recognized:
    #
    # - "\\" (backslash itself)
    # - "\a" (alert)
    # - "\b" (backspace)
    # - "\e" (escape)
    # - "\f" (form feed)
    # - "\n" (new line)
    # - "\r" (carriage return)
    # - "\s" (space)
    # - "\t" (horizontal tab)
    # - "\u{XXXX}" (unicode codepoint)
    # - "\v" (vertical tab)
    # - "\xXX" (hexadecimal character)
    # - "\1".."\9" (numbered capture groups)
    # - "\+" (last capture group)
    # - "\k<name>" (named capture group)
    # - "\&" or "\0" (complete matched text)
    # - "\`" (string before match)
    # - "\'" (string after match)
    #
    # Octal escape sequences are deliberately unsupported to avoid
    # conflict with numbered capture groups.  Rather obscure Emacs
    # style character codes ("\C-x", "\M-\C-x" etc.) are also omitted
    # from this implementation.
    def unescape_replacement(s)
      s.gsub(/\\(?:([\d+&`'\\]|k<\w+>)|u\{([[:xdigit:]]+)\}|x([[:xdigit:]]{2})|(.))/) {
        if c = $1
          BACKSLASH + c
        elsif c = ($2 && [$2.to_i(16)].pack('U')) ||
                  ($3 && [$3.to_i(16)].pack('C'))
          if c == BACKSLASH
            BACKSLASH + c
          else
            c
          end
        else
          UNESCAPE[$4] || $4
        end
      }
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
        context.registers[:agent].credential(@credential_name)
      end
    end

    class LineBreak < Liquid::Tag
      def render(context)
        "\n"
      end
    end
  end
  Liquid::Template.register_tag('credential', LiquidInterpolatable::Tags::Credential)
  Liquid::Template.register_tag('line_break', LiquidInterpolatable::Tags::LineBreak)

  module Blocks
    # Replace every occurrence of a given regex pattern in the first
    # "in" block with the result of the "with" block in which the
    # variable `match` is set for each iteration, which can be used as
    # follows:
    #
    # - `match[0]` or just `match`: the whole matching string
    # - `match[1]`..`match[n]`: strings matching the numbered capture groups
    # - `match.size`: total number of the elements above (n+1)
    # - `match.names`: array of names of named capture groups
    # - `match[name]`..: strings matching the named capture groups
    # - `match.pre_match`: string preceding the match
    # - `match.post_match`: string following the match
    # - `match.***`: equivalent to `match['***']` unless it conflicts with the existing methods above
    #
    # If named captures (`(?<name>...)`) are used in the pattern, they
    # are also made accessible as variables.  Note that if numbered
    # captures are used mixed with named captures, you could get
    # unexpected results.
    #
    # Example usage:
    #
    #     {% regex_replace "\w+" in %}Use me like this.{% with %}{{ match | capitalize }}{% endregex_replace %}
    #     {% assign fullname = "Doe, John A." %}
    #     {% regex_replace_first "\A(?<name1>.+), (?<name2>.+)\z" in %}{{ fullname }}{% with %}{{ name2 }} {{ name1 }}{% endregex_replace_first %}
    #
    #     Use Me Like This.
    #
    #     John A. Doe
    #
    class RegexReplace < Liquid::Block
      Syntax = /\A\s*(#{Liquid::QuotedFragment})(?:\s+in)?\s*\z/

      def initialize(tag_name, markup, tokens)
        super

        case markup
        when Syntax
          @regexp = $1
        else
          raise Liquid::SyntaxError, 'Syntax Error in regex_replace tag - Valid syntax: regex_replace pattern in'
        end
        @nodelist = @in_block = []
        @with_block = nil
      end

      def nodelist
        if @with_block
          @in_block + @with_block
        else
          @in_block
        end
      end

      def unknown_tag(tag, markup, tokens)
        return super unless tag == 'with'.freeze
        @nodelist = @with_block = []
      end

      def render(context)
        begin
          regexp = Regexp.new(context[@regexp].to_s)
        rescue ::SyntaxError => e
          raise Liquid::SyntaxError, "Syntax Error in regex_replace tag - #{e.message}"
        end

        subject = render_all(@in_block, context)

        subject.send(first? ? :sub : :gsub, regexp) {
          next '' unless @with_block
          m = Regexp.last_match
          context.stack do
            m.names.each do |name|
              context[name] = m[name]
            end
            context['match'.freeze] = m
            render_all(@with_block, context)
          end
        }
      end

      def first?
        @tag_name.end_with?('_first'.freeze)
      end
    end
  end
  Liquid::Template.register_tag('regex_replace',       LiquidInterpolatable::Blocks::RegexReplace)
  Liquid::Template.register_tag('regex_replace_first', LiquidInterpolatable::Blocks::RegexReplace)
end
