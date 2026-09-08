module Faraday
  class Response
    # Streams the response and aborts once it exceeds the limit, so that no
    # more than the limit is ever held in memory.
    #
    #   Faraday.new { |builder| builder.use Faraday::Response::SizeLimit, limit: 5.megabytes }
    class SizeLimit < Middleware
      class ResponseTooLarge < Faraday::Error; end

      def initialize(app, limit:)
        super(app)
        @limit = limit
      end

      def call(env)
        body = +""
        env.request.on_data = proc { |chunk, received_bytes, *|
          raise ResponseTooLarge, "response exceeds #{@limit} bytes" if received_bytes > @limit

          body << chunk
        }
        @app.call(env).on_complete { |response_env| response_env.body = body }
      end
    end
  end
end
