require 'date'
require 'cgi'

module Agents
  class JavaScriptAgent < Agent
    default_schedule "never"

    description <<-MD
      This Agent allows you to write code in JavaScript that can create and receive events.  If other Agents aren't meeting your needs, try this one!

      You can put code in the `code` option, or put your code in a Credential and reference it from `code` with `credential:<name>` (recommended).

      You can implement `Agent.check` and `Agent.receive` as you see fit.  The following methods will be available on Agent in the JavaScript environment:

      * `this.createEvent(payload)`
      * `this.incomingEvents()`
      * `this.memory()`
      * `this.memory(key)`
      * `this.memory(keyToSet, valueToSet)`
      * `this.options()`
      * `this.options(key)`
      * `this.log(message)`
      * `this.error(message)`
    MD

    def validate_options
      cred_name = credential_referenced_by_code
      if cred_name
        errors.add(:base, "The credential '#{cred_name}' referenced by code cannot be found") unless credential(cred_name).present?
      else
        errors.add(:base, "The 'code' option is required") unless options['code'].present?
      end
    end

    def working?
      return false if recent_error_logs?

      if options['expected_update_period_in_days'].present?
        return false unless event_created_within?(options['expected_update_period_in_days'])
      end

      if options['expected_receive_period_in_days'].present?
        return false unless last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago
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
        "code" => js_code.gsub(/[\n\r\t]/, '').strip,
        'expected_receive_period_in_days' => "2",
        'expected_update_period_in_days' => "2"
      }
    end

    private

    def execute_js(js_function, incoming_events = [])
      js_function = js_function == "check" ? "check" : "receive"
      context = V8::Context.new
      context.eval(setup_javascript)

      context["doCreateEvent"] = lambda { |a, y| create_event(payload: clean_nans(JSON.parse(y))).payload.to_json }
      context["getIncomingEvents"] = lambda { |a| incoming_events.to_json }
      context["getOptions"] = lambda { |a, x| options.to_json }
      context["doLog"] = lambda { |a, x| log x }
      context["doError"] = lambda { |a, x| error x }
      context["getMemory"] = lambda do |a, x, y|
        if x && y
          memory[x] = clean_nans(y)
        else
          memory.to_json
        end
      end

      context.eval(code)
      context.eval("Agent.#{js_function}();")
    end

    def code
      cred = credential_referenced_by_code
      if cred
        credential(cred) || 'Agent.check = function() { this.error("Unable to find credential"); };'
      else
        options['code']
      end
    end

    def credential_referenced_by_code
      options['code'] =~ /\Acredential:(.*)\Z/ && $1
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
            getMemory(key, value);
          } else if (typeof(key) !== "undefined") {
            return JSON.parse(getMemory())[key];
          } else {
            return JSON.parse(getMemory());
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

        Agent.check = function(){};
        Agent.receive = function(){};
      JS
    end

    def log_errors
      begin
        yield
      rescue V8::Error => e
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
