require "omniauth-oauth2"

module OmniAuth
  module Strategies
    # OmniAuth strategy for Meta Threads.
    class Threads < OmniAuth::Strategies::OAuth2
      option :name, "threads"

      option :client_options, {
        site: "https://graph.threads.net",
        authorize_url: "https://threads.net/oauth/authorize",
        token_url: "/oauth/access_token",
        auth_scheme: :request_body,
      }

      option :authorize_options, %i[scope]
      option :scope, "threads_basic,threads_content_publish"

      uid do
        raw_info["id"].presence || access_token.params["user_id"]
      end

      info do
        username = raw_info["username"].presence || raw_info["name"].presence || uid

        {
          nickname: username,
          name: raw_info["name"].presence || username,
        }
      end

      extra do
        { raw_info: raw_info }
      end

      def callback_url
        options[:redirect_uri] || (full_host + callback_path)
      end

      def raw_info
        @raw_info ||= begin
          response = access_token.get("/me", params: { fields: "id,username,name" })
          response.parsed || {}
        rescue StandardError
          { "id" => access_token.params["user_id"] }.compact
        end
      end
    end
  end
end
