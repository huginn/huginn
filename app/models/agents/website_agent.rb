require 'nokogiri'
require 'faraday'
require 'faraday_middleware'
require 'date'

module Agents
  class WebsiteAgent < Agent

    default_schedule "every_12h"

    UNIQUENESS_LOOK_BACK = 200
    UNIQUENESS_FACTOR = 3

    description <<-MD
      The WebsiteAgent scrapes a website, XML document, or JSON feed and creates Events based on the results.

      Specify a `url` and select a `mode` for when to create Events based on the scraped data, either `all` or `on_change`.

      `url` can be a single url, or an array of urls (for example, for multiple pages with the exact same structure but different content to scrape)

      The `type` value can be `xml`, `html`, or `json`.

      To tell the Agent how to parse the content, specify `extract` as a hash with keys naming the extractions and values of hashes.

      When parsing HTML or XML, these sub-hashes specify how to extract with either a `css` CSS selector or a `xpath` XPath expression and either `"text": true` or `attr` pointing to an attribute name to grab.  An example:

          "extract": {
            "url": { "css": "#comic img", "attr": "src" },
            "title": { "css": "#comic img", "attr": "title" },
            "body_text": { "css": "div.main", "text": true }
          }

      When parsing JSON, these sub-hashes specify [JSONPaths](http://goessner.net/articles/JsonPath/) to the values that you care about.  For example:

          "extract": {
            "title": { "path": "results.data[*].title" },
            "description": { "path": "results.data[*].description" }
          }

      Note that for all of the formats, whatever you extract MUST have the same number of matches for each extractor.  E.g., if you're extracting rows, all extractors must match all rows.  For generating CSS selectors, something like [SelectorGadget](http://selectorgadget.com) may be helpful.

      Can be configured to use HTTP basic auth by including the `basic_auth` parameter with `"username:password"`, or `["username", "password"]`.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.  This is only used to set the "working" status.

      Set `uniqueness_look_back` to limit the number of events checked for uniqueness (typically for performance).  This defaults to the larger of #{UNIQUENESS_LOOK_BACK} or #{UNIQUENESS_FACTOR}x the number of detected received results.

      Set `force_encoding` to an encoding name if the website does not return a Content-Type header with a proper charset.

      Set `user_agent` to a custom User-Agent name if the website does not like the default value ("Faraday v#{Faraday::VERSION}").

      The `headers` field is optional.  When present, it should be a hash of headers to send with the request.

      The WebsiteAgent can also scrape based on incoming events. It will scrape the url contained in the `url` key of the incoming event payload.
    MD

    event_description do
      "Events will have the fields you specified.  Your options look like:\n\n    #{Utils.pretty_print options['extract']}"
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
            'url' => { 'css' => "#comic img", 'attr' => "src" },
            'title' => { 'css' => "#comic img", 'attr' => "alt" },
            'hovertext' => { 'css' => "#comic img", 'attr' => "title" }
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
        errors.add(:base, "mode must be set to on_change or all") unless %w[on_change all].include?(options['mode'])
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

      if options['user_agent'].present?
        errors.add(:base, "user_agent must be a string") unless options['user_agent'].is_a?(String)
      end

      unless headers.is_a?(Hash)
        errors.add(:base, "if provided, headers must be a hash")
      end

      begin
        basic_auth_credentials()
      rescue => e
        errors.add(:base, e.message)
      end
    end

    def check
      check_url options['url']
    end

    def check_url(in_url)
      return unless in_url.present?

      Array(in_url).each do |url|
        log "Fetching #{url}"
        response = faraday.get(url)
        if response.success?
          body = response.body
          if (encoding = options['force_encoding']).present?
            body = body.encode(Encoding::UTF_8, encoding)
          end
          doc = parse(body)

          if extract_full_json?
            if store_payload!(previous_payloads(1), doc)
              log "Storing new result for '#{name}': #{doc.inspect}"
              create_event :payload => doc
            end
          else
            output = {}
            options['extract'].each do |name, extraction_details|
              if extraction_type == "json"
                result = Utils.values_at(doc, extraction_details['path'])
                log "Extracting #{extraction_type} at #{extraction_details['path']}: #{result}"
              else
                case
                when css = extraction_details['css']
                  nodes = doc.css(css)
                when xpath = extraction_details['xpath']
                  nodes = doc.xpath(xpath)
                else
                  error '"css" or "xpath" is required for HTML or XML extraction'
                  return
                end
                unless Nokogiri::XML::NodeSet === nodes
                  error "The result of HTML/XML extraction was not a NodeSet"
                  return
                end
                result = nodes.map { |node|
                  if extraction_details['attr']
                    node.attr(extraction_details['attr'])
                  elsif extraction_details['text']
                    node.text()
                  else
                    error '"attr" or "text" is required on HTML or XML extraction patterns'
                    return
                  end
                }
                log "Extracting #{extraction_type} at #{xpath || css}: #{result}"
              end
              output[name] = result
            end

            num_unique_lengths = options['extract'].keys.map { |name| output[name].length }.uniq

            if num_unique_lengths.length != 1
              error "Got an uneven number of matches for #{options['name']}: #{options['extract'].inspect}"
              return
            end

            old_events = previous_payloads num_unique_lengths.first
            num_unique_lengths.first.times do |index|
              result = {}
              options['extract'].keys.each do |name|
                result[name] = output[name][index]
                if name.to_s == 'url'
                  result[name] = (response.env[:url] + result[name]).to_s
                end
              end

              if store_payload!(old_events, result)
                log "Storing new parsed result for '#{name}': #{result.inspect}"
                create_event :payload => result
              end
            end
          end
        else
          error "Failed: #{response.inspect}"
        end
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        url_to_scrape = event.payload['url']
        check_url(url_to_scrape) if url_to_scrape =~ /^https?:\/\//i
      end
    end

    private

    # This method returns true if the result should be stored as a new event.
    # If mode is set to 'on_change', this method may return false and update an existing
    # event to expire further in the future.
    def store_payload!(old_events, result)
      if !options['mode'].present?
        return true
      elsif options['mode'].to_s == "all"
        return true
      elsif options['mode'].to_s == "on_change"
        result_json = result.to_json
        old_events.each do |old_event|
          if old_event.payload.to_json == result_json
            old_event.expires_at = new_event_expiration_date
            old_event.save!
            return false
         end
        end
        return true
      end
      raise "Illegal options[mode]: " + options['mode'].to_s
    end

    def previous_payloads(num_events)
      if options['uniqueness_look_back'].present?
        look_back = options['uniqueness_look_back'].to_i
      else
        # Larger of UNIQUENESS_FACTOR * num_events and UNIQUENESS_LOOK_BACK
        look_back = UNIQUENESS_FACTOR * num_events
        if look_back < UNIQUENESS_LOOK_BACK
          look_back = UNIQUENESS_LOOK_BACK
        end
      end
      events.order("id desc").limit(look_back) if options['mode'].present? && options['mode'].to_s == "on_change"
    end

    def extract_full_json?
      !options['extract'].present? && extraction_type == "json"
    end

    def extraction_type
      (options['type'] || begin
        if options['url'] =~ /\.(rss|xml)$/i
          "xml"
        elsif options['url'] =~ /\.json$/i
          "json"
        else
          "html"
        end
      end).to_s
    end

    def parse(data)
      case extraction_type
        when "xml"
          Nokogiri::XML(data)
        when "json"
          JSON.parse(data)
        when "html"
          Nokogiri::HTML(data)
        else
          raise "Unknown extraction type #{extraction_type}"
      end
    end

    def is_positive_integer?(value)
      begin
        Integer(value) >= 0
      rescue
        false
      end
    end

    def faraday
      @faraday ||= Faraday.new { |builder|
        builder.headers = headers if headers.length > 0

        if (user_agent = options['user_agent']).present?
          builder.headers[:user_agent] = user_agent
        end

        builder.use FaradayMiddleware::FollowRedirects
        builder.request :url_encoded
        if userinfo = basic_auth_credentials()
          builder.request :basic_auth, *userinfo
        end

        case backend = faraday_backend
        when :typhoeus
          require 'typhoeus/adapters/faraday'
        end
        builder.adapter backend
      }
    end

    def faraday_backend
      ENV.fetch('FARADAY_HTTP_BACKEND', 'typhoeus').to_sym
    end

    def basic_auth_credentials
      case value = options['basic_auth']
      when nil, ''
        return nil
      when Array
        return value if value.size == 2
      when /:/
        return value.split(/:/, 2)
      end
      raise "bad value for basic_auth: #{value.inspect}"
    end

    def headers
      options['headers'].presence || {}
    end
  end
end
