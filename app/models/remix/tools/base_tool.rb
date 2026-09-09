module Remix
  module Tools
    class BaseTool
      attr_reader :user

      def initialize(user)
        @user = user
      end

      def self.tool_name
        raise NotImplementedError
      end

      def self.description
        raise NotImplementedError
      end

      def self.parameters
        raise NotImplementedError
      end

      def self.to_openai_tool
        {
          type: 'function',
          function: {
            name: tool_name,
            description: description,
            parameters: parameters
          }
        }
      end

      def execute(params)
        raise NotImplementedError
      end

      # Mark operation as requiring confirmation
      def requires_confirmation?
        false
      end

      def confirmation_message(params)
        "Are you sure you want to proceed with this operation?"
      end

      protected

      def success_response(message, data = {})
        { success: true, message: message }.merge(data)
      end

      def error_response(message, errors = [])
        { success: false, message: message, errors: errors }
      end
    end
  end
end
