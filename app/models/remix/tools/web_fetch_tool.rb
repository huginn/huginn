module Remix
  module Tools
    class WebFetchTool < BaseTool
      def self.tool_name = 'web_fetch'
      def self.description = 'Fetch and read the content of a web page. Returns the text content of the page, useful for understanding page structure before creating WebsiteAgents.'
      def self.parameters
        {
          type: 'object',
          properties: {
            url: { type: 'string', description: 'The URL of the page to fetch' },
            selector: { type: 'string', description: 'Optional CSS selector to extract specific content' },
            format: {
              type: 'string',
              enum: %w[text html headers],
              description: 'What to return: text (default), html (raw HTML), or headers (HTTP headers only)'
            }
          },
          required: %w[url]
        }
      end

      MAX_CONTENT_LENGTH = 50_000 # ~50KB of text content

      def execute(params)
        url = params['url'].to_s.strip
        return error_response('URL is required') if url.blank?

        begin
          uri = URI.parse(url)
          return error_response('Invalid URL scheme — use http or https') unless %w[http https].include?(uri.scheme)
        rescue URI::InvalidURIError => e
          return error_response("Invalid URL: #{e.message}")
        end

        format = params['format'] || 'text'
        selector = params['selector']

        begin
          response = fetch_url(url)

          case format
          when 'headers'
            headers = {}
            response.each_header { |k, v| headers[k] = v }
            success_response("Fetched headers from #{url}", {
              status: response.code.to_i,
              headers: headers
            })

          when 'html'
            body = response.body.to_s.force_encoding('UTF-8')
            if selector
              doc = Nokogiri::HTML(body)
              elements = doc.css(selector)
              html = elements.map(&:to_html).join("\n")
              html = truncate_content(html)
              success_response("Fetched HTML from #{url} (selector: #{selector})", {
                status: response.code.to_i,
                content: html,
                matches: elements.size
              })
            else
              body = truncate_content(body)
              success_response("Fetched HTML from #{url}", {
                status: response.code.to_i,
                content: body
              })
            end

          else # text
            body = response.body.to_s.force_encoding('UTF-8')
            doc = Nokogiri::HTML(body)

            # Remove script and style elements
            doc.css('script, style, noscript, iframe').remove

            if selector
              elements = doc.css(selector)
              text = elements.map { |el| el.text.strip }.reject(&:blank?).join("\n\n")
              text = truncate_content(text)
              success_response("Fetched text from #{url} (selector: #{selector})", {
                status: response.code.to_i,
                content: text,
                matches: elements.size,
                title: doc.at_css('title')&.text&.strip
              })
            else
              text = extract_readable_text(doc)
              text = truncate_content(text)
              success_response("Fetched text from #{url}", {
                status: response.code.to_i,
                content: text,
                title: doc.at_css('title')&.text&.strip
              })
            end
          end

        rescue Net::OpenTimeout, Net::ReadTimeout
          error_response("Timeout fetching #{url}")
        rescue Errno::ECONNREFUSED
          error_response("Connection refused by #{url}")
        rescue SocketError => e
          error_response("DNS error: #{e.message}")
        rescue => e
          error_response("Fetch error: #{e.message}")
        end
      end

      private

      def fetch_url(url, redirect_limit = 5)
        raise "Too many redirects" if redirect_limit == 0

        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.open_timeout = 15
        http.read_timeout = 30

        request = Net::HTTP::Get.new(uri.request_uri)
        request['User-Agent'] = 'Huginn Remix/1.0'
        request['Accept'] = 'text/html,application/xhtml+xml,*/*'

        response = http.request(request)

        case response
        when Net::HTTPRedirection
          location = response['location']
          location = URI.join(url, location).to_s if location && !location.start_with?('http')
          fetch_url(location, redirect_limit - 1)
        else
          response
        end
      end

      def extract_readable_text(doc)
        # Try to extract main content areas first
        main = doc.at_css('main, article, [role="main"], .content, #content')
        target = main || doc.at_css('body') || doc

        # Get text, clean up whitespace
        text = target.text
          .gsub(/[ \t]+/, ' ')        # collapse horizontal whitespace
          .gsub(/\n{3,}/, "\n\n")     # collapse vertical whitespace
          .strip

        text
      end

      def truncate_content(text)
        return text if text.length <= MAX_CONTENT_LENGTH
        text[0, MAX_CONTENT_LENGTH] + "\n\n... [Content truncated at #{MAX_CONTENT_LENGTH} characters]"
      end
    end
  end
end
