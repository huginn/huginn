require 'nokogiri'
require 'date'

module Agents
  class WebsiteAgent < Agent
    include WebRequestConcern

    can_dry_run!

    default_schedule "every_12h"

    UNIQUENESS_LOOK_BACK = 200
    UNIQUENESS_FACTOR = 3

    description <<-MD
      The WebsiteAgent scrapes a website, XML document, or JSON feed and creates Events based on the results.

      Specify a `url` and select a `mode` for when to create Events based on the scraped data, either `all` or `on_change`.

      `url` can be a single url, or an array of urls (for example, for multiple pages with the exact same structure but different content to scrape)

      The `type` value can be `xml`, `html`, `json`, or `text`.

      To tell the Agent how to parse the content, specify `extract` as a hash with keys naming the extractions and values of hashes.

      When parsing HTML or XML, these sub-hashes specify how each extraction should be done.  The Agent first selects a node set from the document for each extraction key by evaluating either a CSS selector in `css` or an XPath expression in `xpath`.  It then evaluates an XPath expression in `value` on each node in the node set, converting the result into string.  Here's an example:

          "extract": {
            "url": { "css": "#comic img", "value": "@src" },
            "title": { "css": "#comic img", "value": "@title" },
            "body_text": { "css": "div.main", "value": ".//text()" }
          }

      "@_attr_" is the XPath expression to extract the value of an attribute named _attr_ from a node, and ".//text()" is to extract all the enclosed texts.  You can also use [XPath functions](http://www.w3.org/TR/xpath/#section-String-Functions) like `normalize-space` to strip and squeeze whitespace, `substring-after` to extract part of a text, and `translate` to remove comma from a formatted number, etc.  Note that these functions take a string, not a node set, so what you may think would be written as `normalize-space(.//text())` should actually be `normalize-space(.)`.

      When parsing JSON, these sub-hashes specify [JSONPaths](http://goessner.net/articles/JsonPath/) to the values that you care about.  For example:

          "extract": {
            "title": { "path": "results.data[*].title" },
            "description": { "path": "results.data[*].description" }
          }

      When parsing text, each sub-hash should contain a `regexp` and `index`.  Output text is matched against the regular expression repeatedly from the beginning through to the end, collecting a captured group specified by `index` in each match.  Each index should be either an integer or a string name which corresponds to <code>(?&lt;<em>name</em>&gt;...)</code>.  For example, to parse lines of <code><em>word</em>: <em>definition</em></code>, the following should work:

          "extract": {
            "word": { "regexp": "^(.+?): (.+)$", index: 1 },
            "definition": { "regexp": "^(.+?): (.+)$", index: 2 }
          }

      Or if you prefer names to numbers for index:

          "extract": {
            "word": { "regexp": "^(?<word>.+?): (?<definition>.+)$", index: 'word' },
            "definition": { "regexp": "^(?<word>.+?): (?<definition>.+)$", index: 'definition' }
          }

      To extract the whole content as one event:

          "extract": {
            "content": { "regexp": "\A(?m:.)*\z", index: 0 }
          }

      Beware that `.` does not match the newline character (LF) unless the `m` flag is in effect, and `^`/`$` basically match every line beginning/end.  See [this document](http://ruby-doc.org/core-#{RUBY_VERSION}/doc/regexp_rdoc.html) to learn the regular expression variant used in this service.

      Note that for all of the formats, whatever you extract MUST have the same number of matches for each extractor.  E.g., if you're extracting rows, all extractors must match all rows.  For generating CSS selectors, something like [SelectorGadget](http://selectorgadget.com) may be helpful.

      Can be configured to use HTTP basic auth by including the `basic_auth` parameter with `"username:password"`, or `["username", "password"]`.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.  This is only used to set the "working" status.

      Set `uniqueness_look_back` to limit the number of events checked for uniqueness (typically for performance).  This defaults to the larger of #{UNIQUENESS_LOOK_BACK} or #{UNIQUENESS_FACTOR}x the number of detected received results.

      Set `force_encoding` to an encoding name if the website does not return a Content-Type header with a proper charset.

      Set `user_agent` to a custom User-Agent name if the website does not like the default value (`#{default_user_agent}`).

      The `headers` field is optional.  When present, it should be a hash of headers to send with the request.

      Set `disable_ssl_verification` to `true` to disable ssl verification.

      Set `unzip` to `gzip` to inflate the resource using gzip.

      The WebsiteAgent can also scrape based on incoming events. It will scrape the url contained in the `url` key of the incoming event payload. If you specify `merge` as the mode, it will retain the old payload and update it with the new values.

      In Liquid templating, the following variable is available:

      * `_response_`: A response object with the following keys:

          * `status`: HTTP status as integer. (Almost always 200)

          * `headers`: Response headers; for example, `{{ _response_.headers.Content-Type }}` expands to the value of the Content-Type header.  Keys are insensitive to cases and -/_.
    MD

    event_description do
      "Events will have the following fields:\n\n    %s" % [
        Utils.pretty_print(Hash[options['extract'].keys.map { |key|
          [key, "..."]
        }])
      ]
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && !recent_error_logs?
    end

    def default_options
      {
          'expected_update_period_in_days' => "2",
          'url' => "http://xkcd.com",
          'type' => "html",
          'mode' => "on_change",
          'extract' => {
            'url' => { 'css' => "#comic img", 'value' => "@src" },
            'title' => { 'css' => "#comic img", 'value' => "@alt" },
            'hovertext' => { 'css' => "#comic img", 'value' => "@title" }
          }
      }
    end

    def validate_options
      # Check for required fields
      errors.add(:base, "url and expected_update_period_in_days are required") unless options['expected_update_period_in_days'].present? && options['url'].present?
      if !options['extract'].present? && extraction_type != "json"
        errors.add(:base, "extract is required for all types except json")
      end

      # Check for optional fields
      if options['mode'].present?
        errors.add(:base, "mode must be set to on_change, all or merge") unless %w[on_change all merge].include?(options['mode'])
      end

      if options['expected_update_period_in_days'].present?
        errors.add(:base, "Invalid expected_update_period_in_days format") unless is_positive_integer?(options['expected_update_period_in_days'])
      end

      if options['uniqueness_look_back'].present?
        errors.add(:base, "Invalid uniqueness_look_back format") unless is_positive_integer?(options['uniqueness_look_back'])
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

      validate_web_request_options!
    end

    def check
      check_urls(interpolated['url'])
    end

    def check_urls(in_url)
      return unless in_url.present?

      Array(in_url).each do |url|
        check_url(url)
      end
    end

    def check_url(url, payload = {})
      log "Fetching #{url}"
      response = faraday.get(url)
      raise "Failed: #{response.inspect}" unless response.success?

      interpolation_context.stack {
        interpolation_context['_response_'] = ResponseDrop.new(response)
        body = response.body
        if (encoding = interpolated['force_encoding']).present?
          body = body.encode(Encoding::UTF_8, encoding)
        end
        if interpolated['unzip'] == "gzip"
          body = ActiveSupport::Gzip.decompress(body)
        end
        doc = parse(body)

        if extract_full_json?
          if store_payload!(previous_payloads(1), doc)
            log "Storing new result for '#{name}': #{doc.inspect}"
            create_event payload: payload.merge(doc)
          end
          return
        end

        output =
          case extraction_type
          when 'json'
            extract_json(doc)
          when 'text'
            extract_text(doc)
          else
            extract_xml(doc)
          end

        num_unique_lengths = interpolated['extract'].keys.map { |name| output[name].length }.uniq

        if num_unique_lengths.length != 1
          raise "Got an uneven number of matches for #{interpolated['name']}: #{interpolated['extract'].inspect}"
        end

        old_events = previous_payloads num_unique_lengths.first
        num_unique_lengths.first.times do |index|
          result = {}
          interpolated['extract'].keys.each do |name|
            result[name] = output[name][index]
            if name.to_s == 'url'
              result[name] = (response.env[:url] + result[name]).to_s
            end
          end

          if store_payload!(old_events, result)
            log "Storing new parsed result for '#{name}': #{result.inspect}"
            create_event payload: payload.merge(result)
          end
        end
      }
    rescue => e
      error "Error when fetching url: #{e.message}\n#{e.backtrace.join("\n")}"
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          url_to_scrape = event.payload['url']
          next unless url_to_scrape =~ /^https?:\/\//i
          check_url(url_to_scrape,
                    interpolated['mode'].to_s == "merge" ? event.payload : {})
        end
      end
    end

    private

    # This method returns true if the result should be stored as a new event.
    # If mode is set to 'on_change', this method may return false and update an existing
    # event to expire further in the future.
    def store_payload!(old_events, result)
      case interpolated['mode'].presence
      when 'on_change'
        result_json = result.to_json
        old_events.each do |old_event|
          if old_event.payload.to_json == result_json
            old_event.expires_at = new_event_expiration_date
            old_event.save!
            return false
          end
        end
        true
      when 'all', 'merge', ''
        true
      else
        raise "Illegal options[mode]: #{interpolated['mode']}"
      end
    end

    def previous_payloads(num_events)
      if interpolated['uniqueness_look_back'].present?
        look_back = interpolated['uniqueness_look_back'].to_i
      else
        # Larger of UNIQUENESS_FACTOR * num_events and UNIQUENESS_LOOK_BACK
        look_back = UNIQUENESS_FACTOR * num_events
        if look_back < UNIQUENESS_LOOK_BACK
          look_back = UNIQUENESS_LOOK_BACK
        end
      end
      events.order("id desc").limit(look_back) if interpolated['mode'] == "on_change"
    end

    def extract_full_json?
      !interpolated['extract'].present? && extraction_type == "json"
    end

    def extraction_type
      (interpolated['type'] || begin
        case interpolated['url']
        when /\.(rss|xml)$/i
          "xml"
        when /\.json$/i
          "json"
        when /\.(txt|text)$/i
          "text"
        else
          "html"
        end
      end).to_s
    end

    def extract_each(doc, &block)
      interpolated['extract'].each_with_object({}) { |(name, extraction_details), output|
        output[name] = block.call(extraction_details)
      }
    end

    def extract_json(doc)
      extract_each(doc) { |extraction_details|
        result = Utils.values_at(doc, extraction_details['path'])
        log "Extracting #{extraction_type} at #{extraction_details['path']}: #{result}"
        result
      }
    end

    def extract_text(doc)
      extract_each(doc) { |extraction_details|
        regexp = Regexp.new(extraction_details['regexp'])
        result = []
        doc.scan(regexp) {
          result << Regexp.last_match[extraction_details['index']]
        }
        log "Extracting #{extraction_type} at #{regexp}: #{result}"
        result
      }
    end

    def extract_xml(doc)
      extract_each(doc) { |extraction_details|
        case
        when css = extraction_details['css']
          nodes = doc.css(css)
        when xpath = extraction_details['xpath']
          doc.remove_namespaces! # ignore xmlns, useful when parsing atom feeds
          nodes = doc.xpath(xpath)
        else
          raise '"css" or "xpath" is required for HTML or XML extraction'
        end
        case nodes
        when Nokogiri::XML::NodeSet
          result = nodes.map { |node|
            case value = node.xpath(extraction_details['value'])
            when Float
              # Node#xpath() returns any numeric value as float;
              # convert it to integer as appropriate.
              value = value.to_i if value.to_i == value
            end
            value.to_s
          }
        else
          raise "The result of HTML/XML extraction was not a NodeSet"
        end
        log "Extracting #{extraction_type} at #{xpath || css}: #{result}"
        result
      }
    end

    def parse(data)
      case extraction_type
      when "xml"
        Nokogiri::XML(data)
      when "json"
        JSON.parse(data)
      when "html"
        Nokogiri::HTML(data)
      when "text"
        data
      else
        raise "Unknown extraction type #{extraction_type}"
      end
    end

    def is_positive_integer?(value)
      Integer(value) >= 0
    rescue
      false
    end

    # Wraps Faraday::Response
    class ResponseDrop < LiquidDroppable::Drop
      def headers
        HeaderDrop.new(@object.headers)
      end

      # Integer value of HTTP status
      def status
        @object.status
      end
    end

    # Wraps Faraday::Utilsa::Headers
    class HeaderDrop < LiquidDroppable::Drop
      def before_method(name)
        @object[name.tr('_', '-')]
      end
    end
  end
end
