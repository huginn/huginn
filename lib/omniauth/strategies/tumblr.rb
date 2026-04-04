# frozen_string_literal: true

require "json"
require "omniauth-oauth"
require "uri"

module OmniAuth
  module Strategies
    # OmniAuth strategy for Tumblr.
    class Tumblr < OmniAuth::Strategies::OAuth
      option :name, "tumblr"
      option :client_options, {
        site: "https://www.tumblr.com",
        request_token_path: "/oauth/request_token",
        access_token_path: "/oauth/access_token",
        authorize_path: "/oauth/authorize",
      }

      uid do
        raw_info => { name: }
        name
      end

      info do
        raw_info => { name: }
        blogs =
          case raw_info
          in { blogs: Array => blogs }
            blogs.map { |blog| blog.slice(:name, :url, :title) }
          else
            []
          end

        {
          nickname: name,
          name:,
          blogs:,
          avatar: avatar_url,
        }
      end

      extra do
        {
          raw_info: {
            **raw_info,
            avatar: avatar_url,
          },
        }
      end

      def raw_info
        @raw_info ||= begin
          parse_json(access_token.get("https://api.tumblr.com/v2/user/info").body) => {
            response: { user: }
          }
          user
        end
      end

      def avatar_url
        @avatar_url ||=
          case raw_info
          in { blogs: [{ url: }, *] }
            blog_name = URI.parse(url).host
            response = access_token.get("https://api.tumblr.com/v2/blog/#{blog_name}/avatar").body

            parse_json(response) => { response: { avatar_url: } }
            avatar_url
          else
            nil
          end
      end

      private

      def parse_json(string)
        JSON.parse(string, symbolize_names: true)
      end
    end
  end
end
