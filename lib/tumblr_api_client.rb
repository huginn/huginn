# frozen_string_literal: true

require "faraday"
require "simple_oauth"

# Minimal Tumblr v2 client covering the endpoints Huginn uses.
# rubocop:disable Metrics/ClassLength
class TumblrApiClient
  API_ROOT = "https://api.tumblr.com/"
  USER_AGENT = "Huginn/TumblrApiClient"
  STANDARD_POST_OPTIONS = %i[state tags tweet date markdown slug format].freeze
  POST_OPTIONS = {
    text: %i[title body],
    photo: %i[caption link source],
    quote: %i[quote source],
    link: %i[title url description],
    chat: %i[title conversation],
    audio: %i[caption external_url],
    video: %i[caption embed],
  }.freeze

  def initialize(consumer_key:, consumer_secret:, oauth_token:, oauth_token_secret:)
    @consumer_key = consumer_key
    @consumer_secret = consumer_secret
    @oauth_token = oauth_token
    @oauth_token_secret = oauth_token_secret
  end

  def blog_likes(blog_name, options = {})
    connection.get(
      blog_path(blog_name, "likes"),
      with_api_key(options, %i[limit offset before after])
    ).body
  end

  def posts(blog_name, options = {})
    options = normalized_options(options)
    path = blog_path(blog_name, "posts")
    path += "/#{options[:type]}" if options[:type].present?

    connection.get(path, with_api_key(options)).body
  end

  def reblog(blog_name, options = {})
    connection.post(
      blog_path(blog_name, "post/reblog"),
      normalized_options(options, %i[id reblog_key comment])
    ).body
  end

  private

  attr_reader :consumer_key, :consumer_secret, :oauth_token, :oauth_token_secret

  POST_OPTIONS.each do |type, extra_options|
    define_method(type) do |blog_name, options = {}|
      options = normalized_options(options, STANDARD_POST_OPTIONS + extra_options)
      options = convert_source_array(options) if type == :photo
      create_post(blog_name, type, options)
    end
  end
  public(*POST_OPTIONS.keys)

  def create_post(blog_name, type, options)
    connection.post(
      blog_path(blog_name, "post"),
      options.merge(type: type.to_s)
    ).body
  end

  def with_api_key(options, valid_options = nil)
    { api_key: consumer_key }.merge(normalized_options(options, valid_options))
  end

  def normalized_options(options, valid_options = nil)
    options = options.to_h.deep_symbolize_keys.compact
    validate_options(valid_options, options) if valid_options
    options[:tags] = options[:tags].join(",") if options[:tags].is_a?(Array)
    options
  end

  def validate_options(valid_options, options)
    invalid_options = options.keys - valid_options
    return if invalid_options.empty?

    raise ArgumentError, "Invalid options (#{invalid_options.join(', ')}) passed, only #{valid_options} allowed."
  end

  def convert_source_array(options)
    case options
    in { source: Array => sources, **rest }
      {
        **rest,
        **sources.each_with_index.to_h { |source, index|
          ["source[#{index}]", source]
        },
      }
    else
      options
    end
  end

  def connection
    @connection ||= Faraday.new(url: API_ROOT, headers: default_headers) do |builder|
      builder.use(
        Oauth1Authorization,
        consumer_key: consumer_key,
        consumer_secret: consumer_secret,
        oauth_token: oauth_token,
        oauth_token_secret: oauth_token_secret
      )
      builder.request :url_encoded
      builder.response :tumblr_response_body
      builder.response :json, parser_options: { symbolize_names: true }
      builder.adapter Faraday.default_adapter
    end
  end

  def default_headers
    {
      "Accept" => "application/json",
      "User-Agent" => USER_AGENT,
    }
  end

  def blog_path(blog_name, endpoint)
    "v2/blog/#{full_blog_name(blog_name)}/#{endpoint}"
  end

  def full_blog_name(blog_name)
    blog_name.include?(".") ? blog_name : "#{blog_name}.tumblr.com"
  end

  # Faraday request middleware that injects an OAuth 1.0 Authorization header.
  class Oauth1Authorization < Faraday::Middleware
    QUERY_METHODS = %i[get delete].freeze

    def initialize(app, consumer_key:, consumer_secret:, oauth_token:, oauth_token_secret:)
      super(app)
      @consumer_key = consumer_key
      @consumer_secret = consumer_secret
      @oauth_token = oauth_token
      @oauth_token_secret = oauth_token_secret
    end

    def call(env)
      env.request_headers["Authorization"] = oauth_header(env)
      app.call(env)
    end

    private

    attr_reader :consumer_key, :consumer_secret, :oauth_token, :oauth_token_secret

    def oauth_header(env)
      SimpleOAuth::Header.new(
        env.method,
        signature_url(env.url),
        signature_params(env),
        oauth_credentials
      ).to_s
    end

    def signature_params(env)
      stringify_values(query_request?(env) ? query_params(env) : env.body)
    end

    def query_request?(env)
      QUERY_METHODS.include?(env.method)
    end

    def query_params(env)
      Faraday::Utils.parse_query(env.url.query).to_h
    end

    def signature_url(url)
      url.dup.tap { |uri| uri.query = nil }
    end

    def stringify_values(hash)
      hash.compact.to_h { |key, value| [key.to_s, value.to_s] }
    end

    def oauth_credentials
      {
        consumer_key:,
        consumer_secret:,
        token: oauth_token,
        token_secret: oauth_token_secret,
        ignore_extra_keys: true,
      }
    end
  end

  # Faraday response middleware that unwraps Tumblr's meta/response envelope.
  class ResponseBody < Faraday::Middleware
    SUCCESS_STATUSES = [200, 201].freeze

    def on_complete(env)
      body = env.body || {}

      env.body =
        if SUCCESS_STATUSES.include?(env.status)
          body[:response]
        else
          meta = body[:meta].is_a?(Hash) ? body[:meta] : {}
          response_hash = body[:response]
          response_hash.is_a?(Hash) ? meta.merge(response_hash) : meta
        end
    end
  end

  Faraday::Response.register_middleware tumblr_response_body: ResponseBody
end
# rubocop:enable Metrics/ClassLength
