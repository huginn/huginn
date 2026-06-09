require "faraday"
require "omniauth-oauth2"

module OmniAuth
  module Strategies
    class Raindrop < OmniAuth::Strategies::OAuth2
      option :name, "raindrop"

      option :client_options, {
        site: "https://api.raindrop.io",
        authorize_url: "https://raindrop.io/oauth/authorize",
        token_url: "/v1/oauth/access_token",
      }

      uid { raw_info["_id"].presence || raw_info["id"].presence || access_token.params["user_id"] }

      info do
        username = raw_info["name"].presence || raw_info["email"].presence || uid

        {
          email: raw_info["email"],
          name: username,
          nickname: username,
        }.compact
      end

      extra { { raw_info: raw_info } }

      def callback_url
        options[:redirect_uri] || (full_host + callback_path)
      end

      def raw_info
        @raw_info ||= begin
          response = access_token.get("https://api.raindrop.io/rest/v1/user")
          response.parsed["user"] || response.parsed["item"] || response.parsed || {}
        rescue StandardError
          {}
        end
      end

      protected

      def build_access_token
        verifier = request.params["code"]
        response = token_connection.post("/v1/oauth/access_token") do |request|
          request.body = {
            grant_type: "authorization_code",
            code: verifier,
            client_id: options.client_id,
            client_secret: options.client_secret,
            redirect_uri: callback_url,
          }
        end

        ::OAuth2::AccessToken.from_hash(client, response.body)
      end

      private

      def token_connection
        @token_connection ||= Faraday.new(url: "https://api.raindrop.io") do |builder|
          builder.request :json
          builder.response :json
          builder.adapter Faraday.default_adapter
        end
      end
    end
  end
end
