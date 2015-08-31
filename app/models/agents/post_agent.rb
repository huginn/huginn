require 'nokogiri'
require 'date'

module Agents
  class PostAgent < Agent
    include WebRequestConcern

#    cannot_create_events!
    can_dry_run!
#    can_order_created_events!

    default_schedule "never"

    description <<-MD
      --------TESTING v2--------
      A Post Agent receives events from other agents (or runs periodically), merges those events with the [Liquid-interpolated](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) contents of `payload`, and sends the results as POST (or GET) requests to a specified url.  To skip merging in the incoming event, but still send the interpolated payload, set `no_merge` to `true`.

      The `post_url` field must specify where you would like to send requests. Please include the URI scheme (`http` or `https`).

      The `method` used can be any of `get`, `post`, `put`, `patch`, and `delete`.

      By default, non-GETs will be sent with form encoding (`application/x-www-form-urlencoded`).  Change `content_type` to `json` to send JSON instead.  Change `content_type` to `xml` to send XML, where the name of the root element may be specified using `xml_root`, defaulting to `post`.

      Other Options:

        * `headers` - When present, it should be a hash of headers to send with the request.
        * `basic_auth` - Specify HTTP basic auth parameters: `"username:password"`, or `["username", "password"]`.
        * `disable_ssl_verification` - Set to `true` to disable ssl verification.
        * `user_agent` - A custom User-Agent name (default: "Faraday v#{Faraday::VERSION}").
    MD

#    event_description "Does not produce events."
    event_description do
      "Events will have the following fields:\n\n    %s" % [
        Utils.pretty_print(Hash[options['extract'].keys.map { |key|
          [key, "..."]
        }])
      ]
    end

    def default_options
      {
        'post_url' => "http://www.example.com",
        'expected_receive_period_in_days' => '1',
        'content_type' => 'form',
        'method' => 'post',
        'type' => 'html',
        'payload' => {
          'key' => 'value',
          'something' => 'the event contained {{ somekey }}'
        },
        'headers' => {}
      }
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def method
      (interpolated['method'].presence || 'post').to_s.downcase
    end

    def validate_options
      unless options['post_url'].present? && options['expected_receive_period_in_days'].present?
        errors.add(:base, "post_url and expected_receive_period_in_days are required fields")
      end

      if options['payload'].present? && !options['payload'].is_a?(Hash)
        errors.add(:base, "if provided, payload must be a hash")
      end

      unless %w[post get put delete patch].include?(method)
        errors.add(:base, "method must be 'post', 'get', 'put', 'delete', or 'patch'")
      end

      if options['no_merge'].present? && !%[true false].include?(options['no_merge'].to_s)
        errors.add(:base, "if provided, no_merge must be 'true' or 'false'")
      end

      unless headers.is_a?(Hash)
        errors.add(:base, "if provided, headers must be a hash")
      end

      validate_web_request_options!
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

    def receive(incoming_events)
      incoming_events.each do |event|
        outgoing = interpolated(event)['payload'].presence || {}
        if boolify(interpolated['no_merge'])
          handle outgoing, event.payload
        else
          handle outgoing.merge(event.payload), event.payload
        end
      end
    end

    def check
      handle interpolated['payload'].presence || {}
    end

    private

    def handle(data, payload = {})
      url = interpolated(payload)[:post_url]
      headers = headers()

      case method
      when 'get', 'delete'
        params, body = data, nil
      when 'post', 'put', 'patch'
        params = nil

        case interpolated(payload)['content_type']
        when 'json'
          headers['Content-Type'] = 'application/json; charset=utf-8'
          body = data.to_json
        when 'xml'
          headers['Content-Type'] = 'text/xml; charset=utf-8'
          body = data.to_xml(root: (interpolated(payload)[:xml_root] || 'post'))
        else
          body = data
        end
      else
        error "Invalid method '#{method}'"
      end

      response = faraday.run_request(method.to_sym, url, body, headers) { |request|
        request.params.update(params) if params
      }
      
      interpolation_context.stack {
        interpolation_context['_response_'] = ResponseDrop.new(response)
        body = response.body
        doc = parse(body)

        log "Received (but has not stored) result for '#{name}': #{doc}"          
        
        if extract_full_json?
#          if store_payload!(previous_payloads(1), doc)
            log "Storing new result for '#{name}': #{doc.inspect}"
            create_event payload: payload.merge(doc)
#          end
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

#        old_events = previous_payloads num_unique_lengths.first
#        num_unique_lengths.first.times do |index|
#          result = {}
#          interpolated['extract'].keys.each do |name|
#            result[name] = output[name][index]
#            if name.to_s == 'url'
#              result[name] = (response.env[:url] + result[name]).to_s
#            end
#          end

#          if store_payload!(old_events, result)
            log "Storing new parsed result for '#{name}': #{result.inspect}"
            create_event payload: payload.merge(result)
#          end
#        end
      }
    end
    
    	# This method returns true if the result should be stored as a new event.
    # If mode is set to 'on_change', this method may return false and update an existing
    # event to expire further in the future.
#    def store_payload!(old_events, result)
#      case interpolated['mode'].presence
#      when 'on_change'
#        result_json = result.to_json
#        if found = old_events.find { |event| event.payload.to_json == result_json }
#          found.update!(expires_at: new_event_expiration_date)
#          false
#        else
#          true
#        end
#      when 'all', 'merge', ''
#        true
#      else
#        raise "Illegal options[mode]: #{interpolated['mode']}"
#      end
#    end
#
#    def previous_payloads(num_events)
#      if interpolated['uniqueness_look_back'].present?
#        look_back = interpolated['uniqueness_look_back'].to_i
#      else
#        # Larger of UNIQUENESS_FACTOR * num_events and UNIQUENESS_LOOK_BACK
#        look_back = UNIQUENESS_FACTOR * num_events
#        if look_back < UNIQUENESS_LOOK_BACK
#          look_back = UNIQUENESS_LOOK_BACK
#        end
#      end
#      events.order("id desc").limit(look_back) if interpolated['mode'] == "on_change"
#    end

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
            case value = node.xpath(extraction_details['value'] || '.')
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
