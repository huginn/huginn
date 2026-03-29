require "faraday"
require "faraday/multipart"
require "hashie/mash"

class WeiboApiClient
  API_ROOT = "https://api.weibo.com/2"

  def initialize(access_token:)
    @access_token = access_token
  end

  def statuses
    @statuses ||= Statuses.new(
      form_connection:,
      multipart_connection:
    )
  end

  private

  attr_reader :access_token

  def form_connection
    @form_connection ||= build_connection do |builder|
      builder.use AccessToken, access_token: access_token
      builder.request :url_encoded
    end
  end

  def multipart_connection
    @multipart_connection ||= build_connection do |builder|
      builder.use AccessToken, access_token: access_token
      builder.request :multipart
      builder.request :url_encoded
    end
  end

  def build_connection
    Faraday.new(url: API_ROOT) do |builder|
      yield builder
      builder.response :json, parser_options: { symbolize_names: true }
      builder.response :raise_error
      builder.adapter Faraday.default_adapter
    end
  end

  class AccessToken < Faraday::Middleware
    def initialize(app, access_token:)
      super(app)
      @access_token = access_token
    end

    def call(env)
      case env.method
      when :get
        params = Faraday::Utils.parse_query(env.url.query).to_h
        params["access_token"] = access_token
        env.url.query = Faraday::Utils.build_query(params)
      else
        env.body[:access_token] = access_token
      end

      app.call(env)
    end

    private

    attr_reader :access_token
  end

  class Statuses
    def initialize(form_connection:, multipart_connection:)
      @form_connection = form_connection
      @multipart_connection = multipart_connection
    end

    def update(text)
      Hashie::Mash.new(form_connection.post("statuses/update.json", status: text).body)
    end

    def upload(text, pic, content_type:)
      Hashie::Mash.new(
        multipart_connection.post(
          "statuses/upload.json",
          status: text,
          pic: Faraday::UploadIO.new(pic, content_type, filename_for(pic))
        ).body
      )
    end

    def user_timeline(options)
      Hashie::Mash.new(form_connection.get("statuses/user_timeline.json", options).body)
    end

    private

    attr_reader :form_connection, :multipart_connection

    def filename_for(pic)
      File.basename(pic.path)
    end
  end
end
