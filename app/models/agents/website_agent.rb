require 'nokogiri'
require 'date'

module Agents
  class WebsiteAgent < Agent
    include WebRequestConcern

    can_dry_run!
    can_order_created_events!
    no_bulk_receive!

    default_schedule "every_12h"

    UNIQUENESS_LOOK_BACK = 200
    UNIQUENESS_FACTOR = 3

    description <<-MD
      The Website Agent scrapes a website, XML document, or JSON feed and creates Events based on the results.

      Specify a `url` and select a `mode` for when to create Events based on the scraped data, either `all`, `on_change`, or `merge` (if fetching based on an Event, see below).

      The `url` option can be a single url, or an array of urls (for example, for multiple pages with the exact same structure but different content to scrape).

      The WebsiteAgent can also scrape based on incoming events.

      * Set the `url_from_event` option to a Liquid template to generate the url to access based on the Event.  (To fetch the url in the Event's `url` key, for example, set `url_from_event` to `{{ url }}`.)
      * Alternatively, set `data_from_event` to a Liquid template to use data directly without fetching any URL.  (For example, set it to `{{ html }}` to use HTML contained in the `html` key of the incoming Event.)
      * If you specify `merge` for the `mode` option, Huginn will retain the old payload and update it with new values.

      # Supported Document Types

      The `type` value can be `xml`, `html`, `json`, or `text`.

      To tell the Agent how to parse the content, specify `extract` as a hash with keys naming the extractions and values of hashes.

      Note that for all of the formats, whatever you extract MUST have the same number of matches for each extractor.  E.g., if you're extracting rows, all extractors must match all rows.  For generating CSS selectors, something like [SelectorGadget](http://selectorgadget.com) may be helpful.

      # Scraping HTML and XML

      When parsing HTML or XML, these sub-hashes specify how each extraction should be done.  The Agent first selects a node set from the document for each extraction key by evaluating either a CSS selector in `css` or an XPath expression in `xpath`.  It then evaluates an XPath expression in `value` (default: `.`) on each node in the node set, converting the result into a string.  Here's an example:

          "extract": {
            "url": { "css": "#comic img", "value": "@src" },
            "title": { "css": "#comic img", "value": "@title" },
            "body_text": { "css": "div.main", "value": ".//text()" }
          }

      "@_attr_" is the XPath expression to extract the value of an attribute named _attr_ from a node, and `.//text()` extracts all the enclosed text. To extract the innerHTML, use `./node()`; and to extract the outer HTML, use  `.`.

      You can also use [XPath functions](http://www.w3.org/TR/xpath/#section-String-Functions) like `normalize-space` to strip and squeeze whitespace, `substring-after` to extract part of a text, and `translate` to remove commas from formatted numbers, etc.  Note that these functions take a string, not a node set, so what you may think would be written as `normalize-space(.//text())` should actually be `normalize-space(.)`.

      Beware that when parsing an XML document (i.e. `type` is `xml`) using `xpath` expressions, all namespaces are stripped from the document unless the top-level option `use_namespaces` is set to `true`.

      # Scraping JSON

      When parsing JSON, these sub-hashes specify [JSONPaths](http://goessner.net/articles/JsonPath/) to the values that you care about.  For example:

          "extract": {
            "title": { "path": "results.data[*].title" },
            "description": { "path": "results.data[*].description" }
          }

      The `extract` option can be skipped for the JSON type, causing the full JSON response to be returned.

      # Scraping Text

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

      # General Options

      Can be configured to use HTTP basic auth by including the `basic_auth` parameter with `"username:password"`, or `["username", "password"]`.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.  This is only used to set the "working" status.

      Set `uniqueness_look_back` to limit the number of events checked for uniqueness (typically for performance).  This defaults to the larger of #{UNIQUENESS_LOOK_BACK} or #{UNIQUENESS_FACTOR}x the number of detected received results.

      Set `force_encoding` to an encoding name if the website is known to respond with a missing, invalid, or wrong charset in the Content-Type header.  Note that a text content without a charset is taken as encoded in UTF-8 (not ISO-8859-1).

      Set `user_agent` to a custom User-Agent name if the website does not like the default value (`#{default_user_agent}`).

      The `headers` field is optional.  When present, it should be a hash of headers to send with the request.

      Set `disable_ssl_verification` to `true` to disable ssl verification.

      Set `unzip` to `gzip` to inflate the resource using gzip.

      Set `http_success_codes` to an array of status codes (e.g., `[404, 422]`) to treat HTTP response codes beyond 200 as successes.

      # Liquid Templating

      In Liquid templating, the following variable is available:

      * `_response_`: A response object with the following keys:

          * `status`: HTTP status as integer. (Almost always 200)

          * `headers`: Response headers; for example, `{{ _response_.headers.Content-Type }}` expands to the value of the Content-Type header.  Keys are insensitive to cases and -/_.

      # Ordering Events

      #{description_events_order}
    MD

    event_description do
      "Events will have the following fields:\n\n    %s" % [
        Utils.pretty_print(Hash[options['extract'].keys.map { |key|
          [key, "..."]
        }])
      ]
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
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
      errors.add(:base, "either url, url_from_event, or data_from_event are required") unless options['url'].present? || options['url_from_event'].present? || options['data_from_event'].present?
      errors.add(:base, "expected_update_period_in_days is required") unless options['expected_update_period_in_days'].present?
      validate_extract_options!
      validate_http_success_codes!

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

      validate_web_request_options!
    end

    def validate_http_success_codes!
      consider_success = options["http_success_codes"]
      if consider_success.present?

        if (consider_success.class != Array)
          errors.add(:http_success_codes, "must be an array and specify at least one status code")
        else
          if consider_success.uniq.count != consider_success.count
            errors.add(:http_success_codes, "duplicate http code found")
          else
            if consider_success.any?{|e| e.to_s !~ /^\d+$/ }
              errors.add(:http_success_codes, "please make sure to use only numeric values for code, ex 404, or \"404\"")
            end
          end
        end

      end
    end

    def validate_extract_options!
      extraction_type = (extraction_type() rescue extraction_type(options))
      case extract = options['extract']
      when Hash
        if extract.each_value.any? { |value| !value.is_a?(Hash) }
          errors.add(:base, 'extract must be a hash of hashes.')
        else
          case extraction_type
          when 'html', 'xml'
            extract.each do |name, details|
              case details['css']
              when String
                # ok
              when nil
                case details['xpath']
                when String
                  # ok
                when nil
                  errors.add(:base, "When type is html or xml, all extractions must have a css or xpath attribute (bad extraction details for #{name.inspect})")
                else
                  errors.add(:base, "Wrong type of \"xpath\" value in extraction details for #{name.inspect}")
                end
              else
                errors.add(:base, "Wrong type of \"css\" value in extraction details for #{name.inspect}")
              end

              case details['value']
              when String, nil
                # ok
              else
                errors.add(:base, "Wrong type of \"value\" value in extraction details for #{name.inspect}")
              end
            end
          when 'json'
            extract.each do |name, details|
              case details['path']
              when String
                # ok
              when nil
                errors.add(:base, "When type is json, all extractions must have a path attribute (bad extraction details for #{name.inspect})")
              else
                errors.add(:base, "Wrong type of \"path\" value in extraction details for #{name.inspect}")
              end
            end
          when 'text'
            extract.each do |name, details|
              case regexp = details['regexp']
              when String
                begin
                  re = Regexp.new(regexp)
                rescue => e
                  errors.add(:base, "invalid regexp for #{name.inspect}: #{e.message}")
                end
              when nil
                errors.add(:base, "When type is text, all extractions must have a regexp attribute (bad extraction details for #{name.inspect})")
              else
                errors.add(:base, "Wrong type of \"regexp\" value in extraction details for #{name.inspect}")
              end

              case index = details['index']
              when Integer, /\A\d+\z/
                # ok
              when String
                if re && !re.names.include?(index)
                  errors.add(:base, "no named capture #{index.inspect} found in regexp for #{name.inspect})")
                end
              when nil
                errors.add(:base, "When type is text, all extractions must have an index attribute (bad extraction details for #{name.inspect})")
              else
                errors.add(:base, "Wrong type of \"index\" value in extraction details for #{name.inspect}")
              end
            end
          when /\{/
            # Liquid templating
          else
            errors.add(:base, "Unknown extraction type #{extraction_type.inspect}")
          end
        end
      when nil
        unless extraction_type == 'json'
          errors.add(:base, 'extract is required for all types except json')
        end
      else
        errors.add(:base, 'extract must be a hash')
      end
    end

    def check
      check_urls(interpolated['url'])
    end

    def check_urls(in_url, existing_payload = {})
      return unless in_url.present?

      Array(in_url).each do |url|
        check_url(url, existing_payload)
      end
    end

    def check_url(url, existing_payload = {})
      unless /\Ahttps?:\/\//i === url
        error "Ignoring a non-HTTP url: #{url.inspect}"
        return
      end
      uri = Utils.normalize_uri(url)
      log "Fetching #{uri}"
      response = faraday.get(uri)

      raise "Failed: #{response.inspect}" unless consider_response_successful?(response)

      interpolation_context.stack {
        interpolation_context['_response_'] = ResponseDrop.new(response)
        handle_data(response.body, response.env[:url], existing_payload)
      }
    rescue => e
      error "Error when fetching url: #{e.message}\n#{e.backtrace.join("\n")}"
    end

    def handle_data(body, url, existing_payload)
      doc = parse(body)

      if extract_full_json?
        if store_payload!(previous_payloads(1), doc)
          log "Storing new result for '#{name}': #{doc.inspect}"
          create_event payload: existing_payload.merge(doc)
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
          if name.to_s == 'url' && url.present?
            result[name] = (url + Utils.normalize_uri(result[name])).to_s
          end
        end

        if store_payload!(old_events, result)
          log "Storing new parsed result for '#{name}': #{result.inspect}"
          create_event payload: existing_payload.merge(result)
        end
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          existing_payload = interpolated['mode'].to_s == "merge" ? event.payload : {}

          if data_from_event = options['data_from_event'].presence
            data = interpolate_options(data_from_event)
            if data.present?
              handle_event_data(data, event, existing_payload)
            else
              error "No data was found in the Event payload using the template #{data_from_event}", inbound_event: event
            end
          else
            url_to_scrape =
              if url_template = options['url_from_event'].presence
                interpolate_options(url_template)
              else
                interpolated['url']
              end
            check_urls(url_to_scrape, existing_payload)
          end
        end
      end
    end

    private
    def consider_response_successful?(response)
      response.success? || begin
        consider_success = options["http_success_codes"]
        consider_success.present? && (consider_success.include?(response.status.to_s) || consider_success.include?(response.status))
      end
    end

    def handle_event_data(data, event, existing_payload)
      handle_data(data, event.payload['url'], existing_payload)
    rescue => e
      error "Error when handling event data: #{e.message}\n#{e.backtrace.join("\n")}", inbound_event: event
    end

    # This method returns true if the result should be stored as a new event.
    # If mode is set to 'on_change', this method may return false and update an existing
    # event to expire further in the future.
    def store_payload!(old_events, result)
      case interpolated['mode'].presence
      when 'on_change'
        result_json = result.to_json
        if found = old_events.find { |event| event.payload.to_json == result_json }
          found.update!(expires_at: new_event_expiration_date)
          false
        else
          true
        end
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

    def extraction_type(interpolated = interpolated())
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

    def use_namespaces?
      if value = interpolated.key?('use_namespaces')
        boolify(interpolated['use_namespaces'])
      else
        interpolated['extract'].none? { |name, extraction_details|
          extraction_details.key?('xpath')
        }
      end
    end

    def extract_each(&block)
      interpolated['extract'].each_with_object({}) { |(name, extraction_details), output|
        output[name] = block.call(extraction_details)
      }
    end

    def extract_json(doc)
      extract_each { |extraction_details|
        result = Utils.values_at(doc, extraction_details['path'])
        log "Extracting #{extraction_type} at #{extraction_details['path']}: #{result}"
        result
      }
    end

    def extract_text(doc)
      extract_each { |extraction_details|
        regexp = Regexp.new(extraction_details['regexp'])
        case index = extraction_details['index']
        when /\A\d+\z/
          index = index.to_i
        end
        result = []
        doc.scan(regexp) {
          result << Regexp.last_match[index]
        }
        log "Extracting #{extraction_type} at #{regexp}: #{result}"
        result
      }
    end

    def extract_xml(doc)
      extract_each { |extraction_details|
        case
        when css = extraction_details['css']
          nodes = doc.css(css)
        when xpath = extraction_details['xpath']
          nodes = doc.xpath(xpath)
        else
          raise '"css" or "xpath" is required for HTML or XML extraction'
        end
        case nodes
        when Nokogiri::XML::NodeSet
          result = nodes.map { |node|
            value = node.xpath(extraction_details['value'] || '.')
            if value.is_a?(Nokogiri::XML::NodeSet)
              child = value.first
              if child && child.cdata?
                value = child.text
              end
            end
            case value
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
      case type = extraction_type
      when "xml"
        doc = Nokogiri::XML(data)
        # ignore xmlns, useful when parsing atom feeds
        doc.remove_namespaces! unless use_namespaces?
        doc
      when "json"
        JSON.parse(data)
      when "html"
        Nokogiri::HTML(data)
      when "text"
        data
      else
        raise "Unknown extraction type: #{type}"
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

    # Wraps Faraday::Utils::Headers
    class HeaderDrop < LiquidDroppable::Drop
      def before_method(name)
        @object[name.tr('_', '-')]
      end
    end
  end
end
