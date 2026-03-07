module Agents
  class PdfInfoAgent < Agent
    include WebRequestConcern

    gem_dependency_check { defined?(PDF::Reader) }

    cannot_be_scheduled!
    no_bulk_receive!

    description <<~MD
      The PDF Info Agent returns the metadata contained within a given PDF file, using the pdf-reader gem.

      #{'## Include the `pdf-reader` gem in your `Gemfile` to use PDFInfo Agents.' if dependencies_missing?}

      It works by acting on events that contain a key `url` in their payload, and extracts PDF metadata from them.

      Options:

      * `basic_auth` - Specify HTTP basic auth parameters: `"username:password"`, or `["username", "password"]`.
      * `disable_ssl_verification` - Set to `true` to disable ssl verification.
      * `user_agent` - A custom User-Agent name.
      * `headers` - A hash of headers to send with the request.
      * `proxy` - A proxy URL to use for the request.
    MD

    event_description do
      "This will change based on the metadata in the pdf.\n\n    " +
        Utils.pretty_print({
          "Title" => "Everyday Rails Testing with RSpec",
          "Author" => "Aaron Sumner",
          "Creator" => "LaTeX with hyperref package",
          "Producer" => "xdvipdfmx (0.7.8)",
          "CreationDate" => "Fri Aug  2 05:32:50 2013",
          "Pages" => "150",
          "Page size" => "612.0 x 792.0 pts",
          "PDF version" => "1.5",
          "url" => "your url",
        })
    end

    def working?
      !recent_error_logs?
    end

    def default_options
      {}
    end

    def validate_options
      validate_web_request_options!
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          check_url(event.payload["url"], event.payload)
        end
      end
    end

    def check_url(in_url, payload)
      return unless in_url.present?

      Array(in_url).each do |url|
        uri = URI(url) rescue nil
        unless uri.is_a?(URI::HTTP)
          error "Unsupported URL: #{url}"
          next
        end

        log "Fetching #{url}"
        response = faraday.get(url)
        reader = PDF::Reader.new(StringIO.new(response.body))

        info = reader.info.to_h { |key, value|
          [key.to_s, decode_pdf_date(value) || value]
        }
        info["Pages"] = reader.page_count.to_s
        if (page = reader.pages.first)
          info["Page size"] = "#{page.width} x #{page.height} pts"
        end
        info["PDF version"] = reader.pdf_version.to_s

        create_event payload: info.merge(payload)
      end
    end

    private

    # Decode a PDF date string (D:YYYYMMDDHHmmSSOHH'mm') into a
    # human-readable format.  Returns nil if the string is not a PDF date.
    def decode_pdf_date(str)
      return unless str.is_a?(String) && /\AD:\d{4}/.match?(str)

      date = str.gsub(/\AD:|'/, "")
      fmt = case date
            when /\A\d{14}[-+Z]/ then "%Y%m%d%H%M%S%z"
            when /\A\d{14}\z/    then "%Y%m%d%H%M%S"
            when /\A\d{12}\z/    then "%Y%m%d%H%M"
            when /\A\d{8}\z/     then "%Y%m%d"
            when /\A\d{4}\z/     then "%Y"
            end or return

      Time.strptime(date, fmt).strftime("%c")
    rescue ArgumentError
      nil
    end
  end
end
