require 'faraday'
require 'faraday_middleware'

module WebRequestConcern
  extend ActiveSupport::Concern

  def validate_web_request_options!
    if options['user_agent'].present?
      errors.add(:base, "user_agent must be a string") unless options['user_agent'].is_a?(String)
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
  end

  def faraday
    faraday_options = {
      ssl: {
        verify: !boolify(options['disable_ssl_verification'])
      }
    }

    @faraday ||= Faraday.new(faraday_options) { |builder|
      builder.headers = headers if headers.length > 0

      builder.headers[:user_agent] = user_agent

      builder.use FaradayMiddleware::FollowRedirects
      builder.request :url_encoded
      if userinfo = basic_auth_credentials
        builder.request :basic_auth, *userinfo
      end

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
      ENV.fetch('DEFAULT_HTTP_USER_AGENT', "Huginn - https://github.com/cantino/huginn")
    end
  end
end
