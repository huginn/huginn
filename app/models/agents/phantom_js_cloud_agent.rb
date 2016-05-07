require 'json'
require 'uri'

include ERB::Util

module Agents
  class PhantomJsCloudAgent < Agent
    include FormConfigurable

    can_dry_run!
    
    default_schedule "every_12h"
    
    description <<-MD
      The Phantom Js Cloud Agent is used to formulate a url in accordance with the PhantomJs Cloud API.

      ** TODO **

      Reference: https://phantomjscloud.com/docs/index.html
    MD

    event_description <<-MD
      Events look like this:
          {
            "url": "..."
          }
    MD

    def default_options
      {
          'url' => "http://xkcd.com",
          'render_type' => "html",
          'user_agent' => "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36"          
      }
    end

    form_configurable :api_key, type: :array, values: ['** TODO ** list of credentials']
    form_configurable :url        
    form_configurable :render_type, type: :array, values: ['html', 'plainText']
    form_configurable :user_agent, type: :text

    def renderType
        interpolated['render_type'].presence || 'html'
    end

    def build_phantom_url(url)
      api_key = interpolated[:api_key]
      request_hash = {
        :url => url,
        :renderType => renderType,
        :requestSettings => {
          :userAgent => interpolated[:user_agent]
        }
      }

      request = request_hash.to_json
      encoded = url_encode(request)

      phantom_url = "https://phantomjscloud.com/api/browser/v2/#{api_key}/?request=#{encoded}"
      log "Generated #{phantom_url}"
      create_event payload: { 'url' => phantom_url }
    end

    def check
      build_phantom_url (interpolated[:url])
    end

    def receive(incoming_events)
      log "receiving..."
      incoming_events.each do |event|
        mo = interpolated(event)
        build_phantom_url (mo['url'])
      end
    end

    def working?
      !recent_error_logs? or received_event_without_error?
    end

    def validate_options
      # Check for required fields
      errors.add(:base, "url is required") unless options['url'].present?
      #errors.add(:base, "credential is required") unless options['api_key'].present?
    end
  end
end
