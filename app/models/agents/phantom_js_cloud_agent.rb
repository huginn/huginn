require 'json'
require 'uri'

module Agents
  class PhantomJsCloudAgent < Agent
    include ERB::Util
    include FormConfigurable
    include WebRequestConcern

    can_dry_run!

    default_schedule 'every_12h'

    description <<-MD
      [PhantomJs Cloud](https://phantomjscloud.com/) renders webpages in much the same way as a browser would, and allows the Website Agent to properly scrape dynamic content from javascript-heavy pages.

      The Phantom Js Cloud Agent is used to formulate a url in accordance with the [PhantomJs Cloud API](https://phantomjscloud.com/docs/index.html).
      This url can then be supplied to Website Agent to fetch and parse content.

      [Sign up](https://dashboard.phantomjscloud.com/dash.html#/signup) to get an api key, and add it in Huginn credentials.


      Options:

      * `Api key` - PhantomJs Cloud API Key credential stored in Huginn
      * `Url` - The url to render
      * `Mode` - Create a new `clean` event or `merge` old payload with new values (default: `clean`)
      * `Render type` - Render as html or plain text without html tags (default: `html`)
      * `Output as json` - Return the page conents and metadata as a JSON object (default: `false`)
      * `Ignore images` - Skip loading of inlined images (default: `false`)
      * `Url agent` - A custom User-Agent name (default: `#{default_user_agent}`)
      * `Wait interval` - Milliseconds to delay rendering after the last resource is finished loading.
      This is useful in case there are any AJAX requests or animations that need to finish up.
      This can safely be set to 0 if you know there are no AJAX or animations you need to wait for (default: `1000`ms)


      As this agent only provides a limited subset of the most commonly used options, you can follow [this guide](https://github.com/cantino/huginn/wiki/Browser-Emulation-Using-PhantomJS-Cloud) to make full use of additional options PhantomJsCloud provides.

    MD

    event_description <<-MD
      Events look like this:
          {
            "url": "..."
          }
    MD

    def default_options
      {
        'mode' => 'clean',
        'url' => 'http://xkcd.com',
        'render_type' => 'html',
        'output_as_json' => false,
        'ignore_images' => false,
        'user_agent' => self.class.default_user_agent,
        'wait_interval' => '1000'
      }
    end

    form_configurable :mode, type: :array, values: ['clean', 'merge']
    form_configurable :api_key, roles: :completable
    form_configurable :url
    form_configurable :render_type, type: :array, values: ['html', 'plainText']
    form_configurable :output_as_json, type: :boolean
    form_configurable :ignore_images, type: :boolean
    form_configurable :user_agent, type: :text
    form_configurable :wait_interval

    def mode
      interpolated['mode'].presence || default_options['mode']
    end

    def render_type
      interpolated['render_type'].presence || default_options['render_type']
    end

    def output_as_json
      boolify(interpolated['output_as_json'].presence ||
      default_options['output_as_json'])
    end

    def ignore_images
      boolify(interpolated['ignore_images'].presence ||
      default_options['ignore_images'])
    end

    def user_agent
      interpolated['user_agent'].presence || self.class.default_user_agent
    end

    def wait_interval
      interpolated['wait_interval'].presence || default_options['wait_interval']
    end

    def page_request_settings
      prs = {}

      prs[:ignoreImages] = ignore_images if ignore_images
      prs[:userAgent] = user_agent if user_agent.present?

      if wait_interval != default_options['wait_interval']
        prs[:wait_interval] = wait_interval
      end

      prs
    end

    def build_phantom_url(interpolated)
      api_key = interpolated[:api_key]
      page_request_hash = {
        url: interpolated[:url],
        renderType: render_type
      }

      page_request_hash[:outputAsJson] = output_as_json if output_as_json

      page_request_settings_hash = page_request_settings

      if page_request_settings_hash.any?
        page_request_hash[:requestSettings] = page_request_settings_hash
      end

      request = page_request_hash.to_json
      log "Generated request: #{request}"

      encoded = url_encode(request)
      "https://phantomjscloud.com/api/browser/v2/#{api_key}/?request=#{encoded}"
    end

    def check
      phantom_url = build_phantom_url(interpolated)

      create_event payload: { 'url' => phantom_url }
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          existing_payload = interpolated['mode'].to_s == 'merge' ? event.payload : {}
          phantom_url = build_phantom_url(interpolated)

          result = { 'url' => phantom_url }
          create_event payload: existing_payload.merge(result)
        end
      end
    end

    def complete_api_key
      user.user_credentials.map { |c| { text: c.credential_name, id: "{% credential #{c.credential_name} %}" } }
    end

    def working?
      !recent_error_logs? || received_event_without_error?
    end

    def validate_options
      # Check for required fields
      errors.add(:base, 'Url is required') unless options['url'].present?
      errors.add(:base, 'API key (credential) is required') unless options['api_key'].present?
    end
  end
end
