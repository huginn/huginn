module Dotenv
  class Error < StandardError; end

  class MissingKeys < Error # :nodoc:
    def initialize(keys)
      key_word = "key#{"s" if keys.size > 1}"
      super("Missing required configuration #{key_word}: #{keys.inspect}")
    end
  end
end
