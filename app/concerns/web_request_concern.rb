require 'faraday'
require 'faraday_middleware'

module WebRequestConcern
  module DoNotEncoder
    def self.encode(params)
      params.map do |key, value|
        value.nil? ? "#{key}" : "#{key}=#{value}"
      end.join('&')
    end

    def self.decode(val)
      [val]
    end
  end

  class CharacterEncoding < Faraday::Middleware
    def initialize(app, force_encoding: nil, default_encoding: nil, unzip: nil)
      super(app)
      @force_encoding   = force_encoding
      @default_encoding = default_encoding
      @unzip            = unzip
    end

    def call(env)
      @app.call(env).on_complete do |env|
        body = env[:body]

        case @unzip
        when 'gzip'.freeze
          body.replace(ActiveSupport::Gzip.decompress(body))
        end

        case
        when @force_encoding
          encoding = @force_encoding
        when body.encoding == Encoding::ASCII_8BIT
          # Not all Faraday adapters support automatic charset
          # detection, so we do that.
          case env[:response_headers][:content_type]
          when /;\s*charset\s*=\s*([^()<>@,;:\\\"\/\[\]?={}\s]+)/i
            encoding = Encoding.find($1) rescue @default_encoding
          when /\A\s*(?:text\/[^\s;]+|application\/(?:[^\s;]+\+)?(?:xml|json))\s*(?:;|\z)/i
            encoding = @default_encoding
          else
            # Never try to transcode a binary content
            next
          end
          # Return body as binary if default_encoding is nil
          next if encoding.nil?
        end
        body.encode!(Encoding::UTF_8, encoding)
      end
    end
  end

  Faraday::Response.register_middleware character_encoding: CharacterEncoding

  extend ActiveSupport::Concern

  def validate_web_request_options!
    if options['user_agent'].present?
      errors.add(:base, "user_agent must be a string") unless options['user_agent'].is_a?(String)
    end
    
    if options['proxy'].present?
      errors.add(:base, "proxy must be a string") unless options['proxy'].is_a?(String)
    end
    
    if options['disable_ssl_verification'].present? && boolify(options['disable_ssl_verification']).nil?
      errors.add(:base, "if provided, disable_ssl_verification must be true or false")
    end

    unless headers(options['headers']).is_a?(Hash)
      errors.add(:base, "if provided, headers must be a hash")
    end

    begin
      basic_auth_credentials(options['basic_auth'])
    rescue ArgumentError => e
      errors.add(:base, e.message)
    end

    if (encoding = options['force_encoding']).present?
      case encoding
      when String
        begin
          Encoding.find(encoding)
        rescue ArgumentError
          errors.add(:base, "Unknown encoding: #{encoding.inspect}")
        end
      else
        errors.add(:base, "force_encoding must be a string")
      end
    end
  end

  # The default encoding for a text content with no `charset`
  # specified in the Content-Type header.  Override this and make it
  # return nil if you want to detect the encoding on your own.
  def default_encoding
    Encoding::UTF_8
  end

  def faraday
    faraday_options = {
      ssl: {
        verify: !boolify(options['disable_ssl_verification'])
      }
    }

    @faraday ||= Faraday.new(faraday_options) { |builder|
      builder.response :character_encoding,
                       force_encoding: interpolated['force_encoding'].presence,
                       default_encoding: default_encoding,
                       unzip: interpolated['unzip'].presence

      builder.headers = headers if headers.length > 0

      builder.headers[:user_agent] = user_agent
      
      builder.proxy interpolated['proxy'].presence

      unless boolify(interpolated['disable_redirect_follow'])
        builder.use FaradayMiddleware::FollowRedirects
      end
      builder.request :multipart
      builder.request :url_encoded

      if boolify(interpolated['disable_url_encoding'])
        builder.options.params_encoder = DoNotEncoder
      end

      if userinfo = basic_auth_credentials
        builder.request :basic_auth, *userinfo
      end

      builder.use FaradayMiddleware::Gzip

      case backend = faraday_backend
        when :typhoeus
          require 'typhoeus/adapters/faraday'
      end
      builder.adapter backend
    }
  end

  def headers(value = interpolated['headers'])
    value.presence || {}
  end

  def basic_auth_credentials(value = interpolated['basic_auth'])
    case value
      when nil, ''
        return nil
      when Array
        return value if value.size == 2
      when /:/
        return value.split(/:/, 2)
    end
    raise ArgumentError.new("bad value for basic_auth: #{value.inspect}")
  end

  def faraday_backend
    ENV.fetch('FARADAY_HTTP_BACKEND', 'typhoeus').to_sym
  end

  def user_agent
    interpolated['user_agent'].presence || self.class.default_user_agent
  end

  module ClassMethods
    def default_user_agent
      ENV.fetch('DEFAULT_HTTP_USER_AGENT', "Huginn - https://github.com/huginn/huginn")
    end
  end
end
