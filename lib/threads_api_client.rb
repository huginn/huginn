require "faraday"

class ThreadsApiClient
  API_ROOT = "https://graph.threads.net/"

  def initialize(access_token_provider:)
    @access_token_provider = access_token_provider
  end

  def account(fields:)
    connection.get("/v1.0/me", { fields: }.compact).body
  end

  def posts(user_id:, fields:, limit:, since: nil)
    query = {
      fields:,
      limit:,
      since:,
    }.compact
    posts = []
    seen_cursors = {}

    loop do
      response = connection.get("/v1.0/#{user_id}/threads", query).body
      page_posts, after = page_posts_and_after(response)
      posts.concat(page_posts)

      break unless after.present?
      break if seen_cursors[after]

      seen_cursors[after] = true
      query = query.merge(after:)
    end

    posts
  end

  def create_text_post(text:, reply_to_id: nil, reply_control: nil)
    connection.post("/v1.0/me/threads", {
      media_type: "TEXT",
      text:,
      reply_to_id:,
      reply_control:,
    }.compact).body
  end

  def publish_post(user_id:, creation_id:)
    connection.post("/v1.0/#{user_id}/threads_publish", {
      creation_id:,
    }).body
  end

  def delete_post(thread_id:)
    connection.delete("/v1.0/#{thread_id}").body
  end

  private

  attr_reader :access_token_provider

  def connection
    @connection ||= Faraday.new(url: API_ROOT) do |builder|
      builder.use AccessToken, access_token_provider: access_token_provider
      builder.request :url_encoded
      builder.response :threads_error_handler
      builder.response :json, parser_options: { symbolize_names: true }
      builder.adapter Faraday.default_adapter
    end
  end

  def page_posts_and_after(response)
    case response
    in { data: Array => posts, paging: { cursors: { after: String => after } } }
      [posts, after]
    in { data: Array => posts }
      [posts, nil]
    else
      [[], nil]
    end
  end

  class AccessToken < Faraday::Middleware
    QUERY_METHODS = %i[get delete].freeze

    def initialize(app, access_token_provider:)
      super(app)
      @access_token_provider = access_token_provider
    end

    def call(env)
      if QUERY_METHODS.include?(env.method)
        params = Faraday::Utils.parse_query(env.url.query).to_h
        params["access_token"] = access_token
        env.url.query = Faraday::Utils.build_query(params)
      else
        env.body = (env.body || {}).merge(access_token: access_token)
      end

      app.call(env)
    end

    private

    attr_reader :access_token_provider

    def access_token
      access_token_provider.call
    end
  end

  class ErrorHandler < Faraday::Middleware
    def call(env)
      app.call(env).on_complete do |response_env|
        next if (200..299).cover?(response_env.status)

        body = response_env.body
        message =
          case body
          in { error: { message: String => message } }
            message
          else
            body.to_s
          end
        raise StandardError, message
      end
    end
  end

  Faraday::Response.register_middleware threads_error_handler: ErrorHandler
end
