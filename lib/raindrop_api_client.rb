require "faraday"

class RaindropApiClient
  API_ROOT = "https://api.raindrop.io/rest/v1/"

  def initialize(access_token_provider:)
    @access_token_provider = access_token_provider
  end

  def raindrops(collection_id:, page: 0, perpage: 50, search: nil, sort: "-created", nested: nil)
    connection.get("raindrops/#{collection_id}", {
      page:,
      perpage:,
      search:,
      sort:,
      nested:,
    }.compact).body.fetch(:items, [])
  end

  def create_raindrop(attributes)
    connection.post("raindrop", attributes.compact).body.fetch(:item)
  end

  private

  attr_reader :access_token_provider

  def connection
    @connection ||= Faraday.new(url: API_ROOT) do |builder|
      builder.use AccessToken, access_token_provider: access_token_provider
      builder.request :json
      builder.response :raindrop_error_handler
      builder.response :json, parser_options: { symbolize_names: true }
      builder.adapter Faraday.default_adapter
    end
  end

  class AccessToken < Faraday::Middleware
    def initialize(app, access_token_provider:)
      super(app)
      @access_token_provider = access_token_provider
    end

    def call(env)
      env.request_headers["Authorization"] = "Bearer #{access_token_provider.call}"
      app.call(env)
    end

    private

    attr_reader :access_token_provider
  end

  class ErrorHandler < Faraday::Middleware
    def call(env)
      app.call(env).on_complete do |response_env|
        next if (200..299).cover?(response_env.status)

        body = response_env.body
        message =
          case body
          in { errorMessage: String => error_message }
            error_message
          in { error: String => error }
            error
          else
            body.to_s
          end
        raise StandardError, message
      end
    end
  end

  Faraday::Response.register_middleware raindrop_error_handler: ErrorHandler
end
