module Liquid
  # https://github.com/Shopify/liquid/pull/2063
  #
  # The Liquid tokenizer does not handle closing braces inside quoted
  # strings.  A `}` in a quoted filter argument (e.g. a regex
  # quantifier like `{2,}`) prematurely terminates the `{{ }}`
  # variable token.
  #
  # Override Tokenizer#next_variable_token to skip over quoted
  # strings.
  class Tokenizer
    SINGLE_QUOTE = "'".ord
    DOUBLE_QUOTE = '"'.ord

    private

    def next_variable_token
      start = @ss.pos - 2

      byte_a = byte_b = @ss.scan_byte

      while byte_b
        byte_a = @ss.scan_byte while byte_a &&
            byte_a != CLOSE_CURLEY && byte_a != OPEN_CURLEY &&
            byte_a != SINGLE_QUOTE && byte_a != DOUBLE_QUOTE

        break unless byte_a

        # Skip over quoted strings so that } inside them is ignored.
        # skip_until does not advance when the closer is missing, which
        # would leave this loop spinning.  An unescaped quote inside a
        # single-quoted path must also not hang parsing.
        if byte_a == SINGLE_QUOTE || byte_a == DOUBLE_QUOTE
          quote = byte_a == SINGLE_QUOTE ? /'/ : /"/
          pos = @ss.pos
          if @ss.skip_until(quote) && @ss.pos > pos
            byte_a = @ss.scan_byte
          else
            byte_a = @ss.scan_byte
            break unless byte_a
          end
          next
        end

        if @ss.eos?
          return byte_a == CLOSE_CURLEY ? @source.byteslice(start, @ss.pos - start) : "{{"
        end

        byte_b = @ss.scan_byte

        if byte_a == CLOSE_CURLEY
          if byte_b == CLOSE_CURLEY
            return @source.byteslice(start, @ss.pos - start)
          else
            @ss.pos -= 1
            return @source.byteslice(start, @ss.pos - start)
          end
        elsif byte_a == OPEN_CURLEY && byte_b == PERCENTAGE
          return next_tag_token_with_start(start)
        end

        byte_a = byte_b
      end

      "{{"
    end
  end
end
