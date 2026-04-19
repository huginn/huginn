require 'date'
require 'cgi'
require 'faraday'
require 'faraday/follow_redirects'
require 'faraday/gzip'
require 'faraday/typhoeus'

module Agents
  class JavaScriptAgent < Agent
    include FormConfigurable

    can_dry_run!

    FETCH_USER_AGENT = "Huginn - https://github.com/huginn/huginn".freeze
    ALLOWED_FETCH_METHODS = %i[get head post put delete patch options].freeze
    URL_POLYFILL_PATH = Rails.root.join("tmp/build/url-polyfill.js").freeze

    def self.url_polyfill_source
      @url_polyfill_source ||= File.read(URL_POLYFILL_PATH)
    rescue Errno::ENOENT
      raise "URL polyfill not found at #{URL_POLYFILL_PATH}. Run `npm install && npm run build`."
    end

    class ConditionalFollowRedirects < Faraday::FollowRedirects::Middleware
      def call(env)
        case env[:request]&.context
        in { skip_follow_redirects: true }
          @app.call(env)
        else
          super
        end
      end
    end

    default_schedule "never"

    gem_dependency_check { defined?(MiniRacer) }

    description <<~MD
      The JavaScript Agent allows you to write code in JavaScript that can create and receive events.  If other Agents aren't meeting your needs, try this one!

      #{'## Include `mini_racer` in your Gemfile to use this Agent!' if dependencies_missing?}

      You can put code in the `code` option, or put your code in a Credential and reference it from `code` with `credential:<name>` (recommended).

      You can implement `Agent.check` and `Agent.receive` as you see fit.  The following methods will be available on Agent in the JavaScript environment:

      * `this.createEvent(payload)`
      * `this.incomingEvents()` (the returned event objects will each have a `payload` property)
      * `this.memory()`
      * `this.memory(key)`
      * `this.memory(keyToSet, valueToSet)`
      * `this.setMemory(object)` (replaces the Agent's memory with the provided object)
      * `this.deleteKey(key)` (deletes a key from memory and returns the value)
      * `this.credential(name)`
      * `this.credential(name, valueToSet)`
      * `this.options()`
      * `this.options(key)`
      * `this.log(message)`
      * `this.error(message)`
      * `this.kvs` (whose properties are variables provided by KeyValueStoreAgents)
      * `this.escapeHtml(htmlToEscape)`
      * `this.unescapeHtml(htmlToUnescape)`

      A synchronous subset of the Web `fetch` API is also available as `Agent.fetch(url, options)`.  It blocks until the response is received and returns a Response-like object with the following members:

      * `ok`, `status`, `statusText`, `url`, `redirected`
      * `headers`: an object whose own properties are the response headers (with lower-cased names), plus `get(name)` and `has(name)` methods for case-insensitive lookup
      * `text()` returning the response body as a string
      * `json()` returning the parsed JSON body

      Supported request options are `method` (default `"GET"`), `headers` (a plain object), `body` (a string), `timeout` (in seconds), and `redirect` (`"follow"` or `"manual"`, default `"follow"`).  Network errors throw a `TypeError`; HTTP error statuses do not — check `response.ok` as per the standard.  A default `User-Agent` header is sent when not overridden by the `headers` option.

      To issue multiple requests in parallel, use `Agent.fetchAll(requests, options)`.  Each request may be a URL string or a `[url, options]` pair mirroring the arguments of `Agent.fetch`.  The return value is an array of Response-like objects in the same order as the input.  As with `Agent.fetch`, any network error throws a `TypeError` for the whole batch, while individual HTTP error statuses are reported via each `response.ok`.  The optional second argument accepts `{ concurrency: 8 }` to cap the number of concurrent requests.

      The WHATWG `URL` and `URLSearchParams` classes are also available as globals.
    MD

    form_configurable :code, type: :text, ace: { mode: 'javascript' }
    form_configurable :expected_receive_period_in_days
    form_configurable :expected_update_period_in_days

    before_validation { self.options['language'] = 'JavaScript' }

    def validate_options
      cred_name = credential_referenced_by_code
      if cred_name
        errors.add(:base,
                   "The credential '#{cred_name}' referenced by code cannot be found") unless credential(cred_name).present?
      else
        errors.add(:base, "The 'code' option is required") unless options['code'].present?
      end

    end

    def working?
      return false if recent_error_logs?

      if interpolated['expected_update_period_in_days'].present?
        return false unless event_created_within?(interpolated['expected_update_period_in_days'])
      end

      if interpolated['expected_receive_period_in_days'].present?
        return false unless last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago
      end

      true
    end

    def check
      log_errors do
        execute_js("check")
      end
    end

    def receive(incoming_events)
      log_errors do
        execute_js("receive", incoming_events)
      end
    end

    def default_options
      js_code = <<-JS
        Agent.check = function() {
          if (this.options('make_event')) {
            this.createEvent({ 'message': 'I made an event!' });
            var callCount = this.memory('callCount') || 0;
            this.memory('callCount', callCount + 1);
          }
        };

        Agent.receive = function() {
          var events = this.incomingEvents();
          for(var i = 0; i < events.length; i++) {
            this.createEvent({ 'message': 'I got an event!', 'event_was': events[i].payload });
          }
        }
      JS

      {
        'code' => Utils.unindent(js_code),
        'language' => 'JavaScript',
        'expected_receive_period_in_days' => '2',
        'expected_update_period_in_days' => '2'
      }
    end

    private

    def execute_js(js_function, incoming_events = [])
      js_function = js_function == "check" ? "check" : "receive"
      context = MiniRacer::Context.new
      context.eval(setup_javascript)

      context.attach("doCreateEvent", ->(y) { create_event(payload: clean_nans(JSON.parse(y))).payload.to_json })
      context.attach("getIncomingEvents", -> { incoming_events.to_json })
      context.attach("getOptions", -> { interpolated.to_json })
      context.attach("doLog", ->(x) { log x; nil })
      context.attach("doError", ->(x) { error x; nil })
      context.attach("getMemory", -> { memory.to_json })
      context.attach("setMemoryKey", ->(x, y) { memory[x] = clean_nans(y) })
      context.attach("setMemory", ->(x) { memory.replace(clean_nans(x)) })
      context.attach("deleteKey", ->(x) { memory.delete(x).to_json })
      context.attach("escapeHtml", ->(x) { CGI.escapeHTML(x) })
      context.attach("unescapeHtml", ->(x) { CGI.unescapeHTML(x) })
      context.attach('getCredential', ->(k) { credential(k); })
      context.attach('setCredential', ->(k, v) { set_credential(k, v) })
      context.attach("doFetch", ->(url, opts) { do_fetch(url, **opts&.deep_symbolize_keys) })
      context.attach("doFetchAll", ->(pairs, opts) {
        pairs = pairs&.map { |(url, o)| [url, o.is_a?(Hash) ? o.deep_symbolize_keys : {}] }
        do_fetch_all(pairs, **opts&.deep_symbolize_keys)
      })
      context.attach("doLoadUrlPolyfill", -> { context.eval(self.class.url_polyfill_source) })

      kvs = Agents::KeyValueStoreAgent.merge(controllers).find_each.to_h { |kvs|
        [kvs.options[:variable], kvs.memory.as_json]
      }
      context.attach("getKeyValueStores", -> { kvs })
      context.eval("Object.defineProperty(Agent, 'kvs', { get: getKeyValueStores })")

      context.eval(code)
      context.eval("Agent.#{js_function}();")
    end

    def code
      cred = credential_referenced_by_code
      if cred
        credential(cred) || 'Agent.check = function() { this.error("Unable to find credential"); };'
      else
        interpolated['code']
      end
    end

    def credential_referenced_by_code
      (interpolated['code'] || '').strip =~ /\Acredential:(.*)\Z/ && $1
    end

    def set_credential(name, value)
      c = user.user_credentials.find_or_initialize_by(credential_name: name)
      c.credential_value = value
      c.save!
    end

    def setup_javascript
      <<-JS
        function Agent() {};

        Agent.createEvent = function(opts) {
          return JSON.parse(doCreateEvent(JSON.stringify(opts)));
        }

        Agent.incomingEvents = function() {
          return JSON.parse(getIncomingEvents());
        }

        Agent.memory = function(key, value) {
          if (typeof(key) !== "undefined" && typeof(value) !== "undefined") {
            setMemoryKey(key, value);
          } else if (typeof(key) !== "undefined") {
            return JSON.parse(getMemory())[key];
          } else {
            return JSON.parse(getMemory());
          }
        }

        Agent.setMemory = function(obj) {
          setMemory(obj);
        }

        Agent.credential = function(name, value) {
          if (typeof(value) !== "undefined") {
            setCredential(name, value);
          } else {
            return getCredential(name);
          }
        }

        Agent.options = function(key) {
          if (typeof(key) !== "undefined") {
            return JSON.parse(getOptions())[key];
          } else {
            return JSON.parse(getOptions());
          }
        }

        Agent.log = function(message) {
          doLog(message);
        }

        Agent.error = function(message) {
          doError(message);
        }

        Agent.deleteKey = function(key) {
          return JSON.parse(deleteKey(key));
        }

        Agent.escapeHtml = function(html) {
          return escapeHtml(html);
        }

        Agent.unescapeHtml = function(html) {
          return unescapeHtml(html);
        }

        Agent.check = function(){};
        Agent.receive = function(){};

        function buildResponse(result) {
          var headers = result.headers;
          return {
            ok: result.ok,
            status: result.status,
            statusText: result.statusText,
            url: result.url,
            redirected: result.redirected,
            headers: Object.assign({}, headers, {
              get: function(name) {
                var key = String(name).toLowerCase();
                return Object.prototype.hasOwnProperty.call(headers, key) ? headers[key] : null;
              },
              has: function(name) {
                return Object.prototype.hasOwnProperty.call(headers, String(name).toLowerCase());
              }
            }),
            text: function() { return result.body; },
            json: function() { return JSON.parse(result.body); }
          };
        }

        Agent.fetch = function(url, options) {
          var result = doFetch(String(url), options || {});
          if (result.error) {
            throw new TypeError(result.error);
          }
          return buildResponse(result);
        };

        ['URL', 'URLSearchParams'].forEach(function(name) {
          Object.defineProperty(globalThis, name, {
            configurable: true,
            get: function() {
              ['URL', 'URLSearchParams'].forEach(function(n) { delete globalThis[n]; });
              doLoadUrlPolyfill();
              return globalThis[name];
            }
          });
        });

        Agent.fetchAll = function(requests, options) {
          if (!Array.isArray(requests)) {
            throw new TypeError("fetchAll requires an array of requests");
          }
          var pairs = requests.map(function(r, i) {
            if (typeof r === "string") return [r, {}];
            if (Array.isArray(r)) {
              if (typeof r[0] !== "string") {
                throw new TypeError("Request at index " + i + ": first element must be a URL string");
              }
              return [r[0], r[1] || {}];
            }
            throw new TypeError("Request at index " + i + " must be a URL string or [url, options] array");
          });
          var results = doFetchAll(pairs, options || {});
          if (results.error) {
            throw new TypeError(results.error);
          }
          return results.map(buildResponse);
        }
      JS
    end

    def log_errors
      yield
    rescue MiniRacer::Error => e
      error "JavaScript error: #{e.message}"
    end

    def fetch_client
      @fetch_client ||= Faraday.new(headers: { "User-Agent" => FETCH_USER_AGENT }) { |b|
        b.use ConditionalFollowRedirects
        b.request :gzip
        b.adapter :typhoeus
      }
    end

    def do_fetch(url, **opts)
      case normalize_fetch_request(url, **opts)
      in { error: } => result
        result
      in req
        build_fetch_result(req, run_fetch_request(**req))
      end
    rescue Faraday::Error => e
      { error: fetch_error_message(e) }
    end

    def do_fetch_all(pairs, concurrency: 8, **_rest)
      return { error: "fetchAll requires an array of requests" } unless pairs.is_a?(Array)

      requests = pairs.map { |(url, opts)| normalize_fetch_request(url, **opts) }
      if (bad = requests.find { it in { error: } })
        return bad.slice(:error)
      end

      concurrency = 8 if concurrency.to_i <= 0
      manager = Faraday::Adapter::Typhoeus.setup_parallel_manager(max_concurrency: concurrency)

      responses = nil
      fetch_client.in_parallel(manager) do
        responses = requests.map { run_fetch_request(**it) }
      end

      results = requests.zip(responses).map { |req, response| build_fetch_result(req, response) }
      if (failed = results.find { it in { error: } })
        return failed.slice(:error)
      end

      results
    rescue Faraday::Error => e
      { error: fetch_error_message(e) }
    end

    def run_fetch_request(url:, method:, headers:, body:, follow:, timeout:)
      fetch_client.run_request(method, url, body, headers) { |r|
        r.options.timeout = timeout if timeout > 0
        r.options.context = { skip_follow_redirects: true } unless follow
      }
    end

    def normalize_fetch_request(url, method: "GET", headers: nil, body: nil, redirect: "follow", timeout: 0, **_rest)
      url = url.to_s
      return { error: "fetch requires a URL" } if url.empty?

      begin
        parsed = URI.parse(url)
      rescue URI::InvalidURIError => e
        return { error: "Invalid URL: #{e.message}" }
      end
      return { error: "Only http and https URLs are supported" } unless parsed.is_a?(URI::HTTP)

      method = method.to_s.downcase.to_sym
      return { error: "Unsupported method: #{method}" } unless ALLOWED_FETCH_METHODS.include?(method)
      return { error: "headers must be an object" } if headers && !headers.is_a?(Hash)
      return { error: "body must be a string" } if body && !body.is_a?(String)

      {
        url:, method:, headers:, body:,
        follow: redirect.to_s != "manual",
        timeout: timeout.to_i,
      }
    end

    def fetch_error_message(e)
      case e
      when Faraday::TimeoutError then "Request timed out: #{e.message}"
      when Faraday::ConnectionFailed then "Connection failed: #{e.message}"
      when Faraday::SSLError then "SSL error: #{e.message}"
      else "Request failed: #{e.message}"
      end
    end

    def build_fetch_result(req, response)
      case response.env
      in { typhoeus_timed_out: true, typhoeus_return_message: msg }
        { error: "Request timed out: #{msg}" }
      in { typhoeus_connection_failed: true, typhoeus_return_message: msg }
        { error: "Connection failed: #{msg}" }
      in env
        final_url = env.url.to_s
        {
          ok: response.status.between?(200, 299),
          status: response.status,
          statusText: Rack::Utils::HTTP_STATUS_CODES[response.status] || "",
          url: final_url,
          redirected: final_url != req[:url],
          headers: response.headers.to_h { |k, v| [k.to_s.downcase, Array(v).join(", ")] },
          body: response.body.to_s,
        }
      end
    end

    def clean_nans(input)
      case input
      when Array
        input.map { |v| clean_nans(v) }
      when Hash
        input.transform_values { |v| clean_nans(v) }
      when Float
        input.nan? ? 'NaN' : input
      else
        input
      end
    end
  end
end
