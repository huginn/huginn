# Monkey patch https://github.com/lostisland/faraday/pull/513
# Fixes encoding issue when passing an URL with non UTF-8 characters
module Faraday
  module Utils
    def unescape(s)
      string = s.to_s
      string.force_encoding(Encoding::BINARY) if RUBY_VERSION >= '1.9'
      CGI.unescape string
    end
  end
end
