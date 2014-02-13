require 'nokogiri'
require 'typhoeus'
require 'date'

module Agents
  class WebsiteAgent < Agent
    cannot_receive_events!

    description <<-MD
      The WebsiteAgent scrapes a website, XML document, or JSON feed and creates Events based on the results.

      Specify a `url` and select a `mode` for when to create Events based on the scraped data, either `all` or `on_change`.

      The `type` value can be `xml`, `html`, or `json`.

      To tell the Agent how to parse the content, specify `extract` as a hash with keys naming the extractions and values of hashes.

      When parsing HTML or XML, these sub-hashes specify how to extract with a `css` CSS selector and either `'text': true` or `attr` pointing to an attribute name to grab.  An example:

          'extract': {
            'url': { 'css': "#comic img", 'attr': "src" },
            'title': { 'css': "#comic img", 'attr': "title" },
            'body_text': { 'css': "div.main", 'text': true }
          }

      When parsing JSON, these sub-hashes specify [JSONPaths](http://goessner.net/articles/JsonPath/) to the values that you care about.  For example:

          'extract': {
            'title': { 'path': "results.data[*].title" },
            'description': { 'path': "results.data[*].description" }
          }

      Note that for all of the formats, whatever you extract MUST have the same number of matches for each extractor.  E.g., if you're extracting rows, all extractors must match all rows.  For generating CSS selectors, something like [SelectorGadget](http://selectorgadget.com) may be helpful.

      Can be configured to use HTTP basic auth by including the `basic_auth` parameter with `username:password`.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent (only used to set the "working" status).

      Set `uniqueness_look_back` (defaults to the larger of 200, 3x the number of received events) to limit the number of events checked for uniqueness (typically for performance).
    MD

    event_description do
      "Events will have the fields you specified.  Your options look like:\n\n    #{Utils.pretty_print options['extract']}"
    end

    default_schedule "every_12h"

    UNIQUENESS_LOOK_BACK = 200
    UNIQUENESS_FACTOR = 3

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def default_options
      {
          'expected_update_period_in_days' => "2",
          'url' => "http://xkcd.com",
          'type' => "html",
          'mode' => :on_change,
          'extract' => {
            'url' => {'css' => "#comic img", 'attr' => "src"},
            'title' => {'css' => "#comic img", 'attr' => "title"}
          }
      }
    end

    def validate_options
      # Check required fields are present
      errors.add(:base, "url and expected_update_period_in_days are required") unless options['expected_update_period_in_days'].present? && options['url'].present?
      if !options['extract'].present? && extraction_type != "json"
        errors.add(:base, "extract is required for all types except json")
      end
      # Check options:
      if options['mode'].present?
        if options['mode'] != "on_change" && options['mode'] != "all"
          errors.add(:base, "mode should be all or on_change")
        end
      end
      # Check integer variables:      
      if options['expected_update_period_in_days'].present?
        begin
          Integer(options['expected_update_period_in_days'])
          rescue
          errors.add(:base, "Invalid expected_update_period_in_days format")
        end
      end
      if options['uniqueness_look_back'].present?
        begin
          Integer(options['uniqueness_look_back'])
          rescue
          errors.add(:base, "Invalid uniqueness_look_back format")
        end      
      end
    end

    def check
      hydra = Typhoeus::Hydra.new
      log "Fetching #{options['url']}"
      request_opts = {:followlocation => true}
      if options['basic_auth'].present?
        request_opts[:userpwd] = options['basic_auth']
      end
      request = Typhoeus::Request.new(options['url'], request_opts)
      request.on_failure do |response|
        error "Failed: #{response.inspect}"
      end
      request.on_success do |response|
        doc = parse(response.body)

        if extract_full_json?
          old_events = previous_payloads 1
          result = doc
          if store_payload? old_events, result
            log "Storing new result for '#{name}': #{result.inspect}"
            create_event :payload => result
          end
        else
          output = {}
          options['extract'].each do |name, extraction_details|
            result = if extraction_type == "json"
                       output[name] = Utils.values_at(doc, extraction_details['path'])
                     else
                       output[name] = doc.css(extraction_details['css']).map { |node|
                         if extraction_details['attr']
                           node.attr(extraction_details['attr'])
                         elsif extraction_details['text']
                           node.text()
                         else
                           error "'attr' or 'text' is required on HTML or XML extraction patterns"
                           return
                         end
                       }
                     end
            log "Extracting #{extraction_type} at #{extraction_details['path'] || extraction_details['css']}: #{result}"
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
                result[name] = URI.join(options['url'], result[name]).to_s if (result[name] =~ URI::DEFAULT_PARSER.regexp[:ABS_URI]).nil?
              end
            end

            if store_payload? old_events, result
              log "Storing new parsed result for '#{name}': #{result.inspect}"
              create_event :payload => result
            end
          end
        end
      end
      hydra.queue request
      hydra.run
    end

    private

    def store_payload?(old_events, result)
      if !options['mode']
        return true
      elsif options['mode'].to_s == "all"
        return true
      elsif options['mode'].to_s == "on_change"
        old_events.each do |old_event|
          if old_event.payload.to_json == result.to_json
            old_event.expires_at = new_event_expiration_date
            old_event.save
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
        # Larger of UNIQUENESS_FACTOR*num_events and UNIQUENESS_LOOK_BACK
        look_back = UNIQUENESS_FACTOR*num_events
        if look_back < UNIQUENESS_LOOK_BACK
          look_back = UNIQUENESS_LOOK_BACK
        end
      end
      events.order("id desc").limit(look_back) if options['mode'].to_s == "on_change"
    end

    def extract_full_json?
      (!options['extract'].present? && extraction_type == "json")
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
  end
end