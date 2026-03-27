module Remix
  module Skills
    class BaseSkill
      class << self
        def name
          raise NotImplementedError
        end

        def description
          raise NotImplementedError
        end

        def triggers
          # Keywords or patterns that activate this skill
          []
        end

        def context(user)
          # Additional context to inject when skill is active
          ""
        end

        def matches?(message)
          triggers.any? { |t| message.downcase.include?(t.downcase) }
        end
      end
    end
  end
end
