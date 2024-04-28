require "English"

module Dotenv
  module Substitutions
    # Substitute variables in a value.
    #
    #   HOST=example.com
    #   URL="https://$HOST"
    #
    module Variable
      class << self
        VARIABLE = /
          (\\)?         # is it escaped with a backslash?
          (\$)          # literal $
          (?!\()        # shouldnt be followed by paranthesis
          \{?           # allow brace wrapping
          ([A-Z0-9_]+)? # optional alpha nums
          \}?           # closing brace
        /xi

        def call(value, env, overwrite: false)
          combined_env = overwrite ? ENV.to_h.merge(env) : env.merge(ENV)
          value.gsub(VARIABLE) do |variable|
            match = $LAST_MATCH_INFO
            substitute(match, variable, combined_env)
          end
        end

        private

        def substitute(match, variable, env)
          if match[1] == "\\"
            variable[1..]
          elsif match[3]
            env.fetch(match[3], "")
          else
            variable
          end
        end
      end
    end
  end
end
