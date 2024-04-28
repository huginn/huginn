module Dotenv
  class Error < StandardError; end

  class MissingKeys < Error # :nodoc:
    def initialize(keys)
      key_word = "key#{(keys.size > 1) ? "s" : ""}"
      super("Missing required configuration #{key_word}: #{keys.inspect}")
    end
  end
end
