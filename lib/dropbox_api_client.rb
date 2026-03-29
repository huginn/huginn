require "faraday"

class DropboxApiClient
  API_ROOT = "https://api.dropboxapi.com/2"

  def initialize(access_token:)
    @access_token = access_token
  end

  def ls(path)
    response = connection.post("files/list_folder", path: normalize_path(path)).body
    entries = response[:entries] || []

    while response[:has_more]
      response = connection.post("files/list_folder/continue", cursor: response.fetch(:cursor)).body
      entries.concat(response[:entries] || [])
    end

    entries.filter_map do |entry|
      case entry
      in { ".tag": "file", path_display:, rev:, server_modified: }
        { "path" => path_display, "rev" => rev, "modified" => server_modified }
      in { ".tag": "file", path_lower:, rev:, server_modified: }
        { "path" => path_lower, "rev" => rev, "modified" => server_modified }
      else
        nil
      end
    end
  end

  def temporary_url_for(path)
    connection.post("files/get_temporary_link", path:).body.tap do |response|
      response[:url] = response.delete(:link)
    end.deep_stringify_keys
  end

  def permanent_url_for(path)
    shared_link = create_shared_link(path)
    shared_link[:url] = force_download(shared_link.fetch(:url))
    shared_link.deep_stringify_keys
  end

  private

  attr_reader :access_token

  def create_shared_link(path)
    connection.post("sharing/create_shared_link_with_settings", path:).body
  rescue Faraday::Error => e
    raise unless shared_link_already_exists?(e)

    links = connection.post("sharing/list_shared_links", path:, direct_only: true).body[:links] || []
    path_lower = path.downcase
    links.find { it in { path_lower: ^path_lower } } || links.first or raise
  end

  def force_download(url)
    uri = URI.parse(url)
    query = URI.decode_www_form(uri.query.to_s).reject { |key, _value| key == "dl" }
    query << ["dl", "1"]
    uri.query = URI.encode_www_form(query)
    uri.to_s
  end

  def normalize_path(path)
    path == "/" ? "" : path
  end

  def connection
    @connection ||= Faraday.new(url: API_ROOT, headers:) do |builder|
      builder.request :json
      builder.response :json, parser_options: { symbolize_names: true }
      builder.response :raise_error
      builder.adapter Faraday.default_adapter
    end
  end

  def headers
    { "Authorization" => "Bearer #{access_token}" }
  end

  def shared_link_already_exists?(error)
    case error.response_body
    in String => body
      case JSON.parse(body, symbolize_names: true)
      in { error_summary: /^shared_link_already_exists\// }
        true
      else
        false
      end
    else
      false
    end
  rescue JSON::ParserError
    false
  end
end
