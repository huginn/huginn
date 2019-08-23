require 'date'
require 'cgi'

module Agents
  class JavaScriptAgent < Agent
    include FormConfigurable

    can_dry_run!

    default_schedule "never"

    gem_dependency_check { defined?(MiniRacer) }

    description <<-MD
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
      * `this.escapeHtml(htmlToEscape)`
      * `this.unescapeHtml(htmlToUnescape)`
    MD

    form_configurable :language, type: :array, values: %w[JavaScript CoffeeScript]
    form_configurable :code, type: :text, ace: true
    form_configurable :expected_receive_period_in_days
    form_configurable :expected_update_period_in_days

    def validate_options
      cred_name = credential_referenced_by_code
      if cred_name
        errors.add(:base, "The credential '#{cred_name}' referenced by code cannot be found") unless credential(cred_name).present?
      else
        errors.add(:base, "The 'code' option is required") unless options['code'].present?
      end

      if interpolated['language'].present? && !interpolated['language'].downcase.in?(%w[javascript coffeescript])
        errors.add(:base, "The 'language' must be JavaScript or CoffeeScript")
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

      context.attach("doCreateEvent", -> (y) { create_event(payload: clean_nans(JSON.parse(y))).payload.to_json })
      context.attach("getIncomingEvents", -> { incoming_events.to_json })
      context.attach("getOptions", -> { interpolated.to_json })
      context.attach("doLog", -> (x) { log x })
      context.attach("doError", -> (x) { error x })
      context.attach("getMemory", -> { memory.to_json })
      context.attach("setMemoryKey", -> (x, y) { memory[x] = clean_nans(y) })
      context.attach("setMemory", -> (x) { memory.replace(clean_nans(x)) })
      context.attach("deleteKey", -> (x) { memory.delete(x).to_json })
      context.attach("escapeHtml", -> (x) { CGI.escapeHTML(x) })
      context.attach("unescapeHtml", -> (x) { CGI.unescapeHTML(x) })
      context.attach('getCredential', -> (k) { credential(k); })
      context.attach('setCredential', -> (k, v) { set_credential(k, v) })

      if (options['language'] || '').downcase == 'coffeescript'
        context.eval(CoffeeScript.compile code)
      else
        context.eval(code)
      end
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
      JS
    end

    def log_errors
      begin
        yield
      rescue MiniRacer::Error => e
        error "JavaScript error: #{e.message}"
      end
    end

    def clean_nans(input)
      if input.is_a?(Array)
        input.map {|v| clean_nans(v) }
      elsif input.is_a?(Hash)
        input.inject({}) { |m, (k, v)| m[k] = clean_nans(v); m }
      elsif input.is_a?(Float) && input.nan?
        'NaN'
      else
        input
      end
    end
  end
end
