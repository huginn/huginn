module Remix
  module Tools
    class EvaluateCodeTool < BaseTool
      def self.tool_name = 'evaluate_code'
      def self.description = 'Execute a JavaScript code snippet in a sandboxed V8 environment. ' \
        'No file system, network, or Huginn system access. ' \
        'Useful for data transformation prototyping, testing Liquid-like logic, ' \
        'JSON manipulation, regex testing, and computing values. ' \
        'The last expression is returned as the result. ' \
        'Use console.log() to capture intermediate output.'
      def self.parameters
        {
          type: 'object',
          properties: {
            code: {
              type: 'string',
              description: 'JavaScript code to execute. The value of the last expression is returned.'
            },
            timeout: {
              type: 'integer',
              description: 'Maximum execution time in milliseconds (default: 5000, max: 10000)'
            }
          },
          required: %w[code]
        }
      end

      MAX_TIMEOUT_MS = 10_000
      DEFAULT_TIMEOUT_MS = 5_000
      MAX_OUTPUT_LENGTH = 50_000

      def execute(params)
        code = params['code'].to_s
        return error_response('Code is required') if code.blank?

        timeout_ms = [(params['timeout'] || DEFAULT_TIMEOUT_MS).to_i, MAX_TIMEOUT_MS].min
        timeout_ms = DEFAULT_TIMEOUT_MS if timeout_ms <= 0

        unless defined?(MiniRacer)
          return error_response('JavaScript engine (MiniRacer) is not available')
        end

        logs = []

        begin
          context = MiniRacer::Context.new(timeout: timeout_ms, max_memory: 32_000_000) # 32MB heap

          # Provide console.log / console.error
          context.attach('__remix_log', ->(msg) {
            logs << { level: 'log', message: msg.to_s }
            nil
          })
          context.attach('__remix_error', ->(msg) {
            logs << { level: 'error', message: msg.to_s }
            nil
          })

          # Minimal sandbox setup: console, JSON helpers, no global access
          context.eval(sandbox_setup)

          # Execute user code, capturing the last expression's value
          result = context.eval(code)

          # Convert result to something JSON-serializable
          result = serialize_result(result)

          output = {
            result: result,
            logs: logs.first(100), # cap logged lines
            type: js_type_name(result)
          }

          success_response("Code executed successfully", output)

        rescue MiniRacer::ScriptTerminatedError
          error_response("Execution timed out after #{timeout_ms}ms", logs: logs.first(100))
        rescue MiniRacer::V8OutOfMemoryError
          error_response("Out of memory (32MB limit)", logs: logs.first(100))
        rescue MiniRacer::ParseError => e
          error_response("Syntax error: #{clean_error(e.message)}", logs: logs.first(100))
        rescue MiniRacer::RuntimeError => e
          error_response("Runtime error: #{clean_error(e.message)}", logs: logs.first(100))
        rescue => e
          error_response("Execution error: #{e.message}")
        ensure
          context&.dispose
        end
      end

      private

      def sandbox_setup
        <<~JS
          // Console
          var console = {
            log: function() {
              var args = Array.prototype.slice.call(arguments);
              __remix_log(args.map(function(a) {
                return typeof a === 'object' ? JSON.stringify(a) : String(a);
              }).join(' '));
            },
            error: function() {
              var args = Array.prototype.slice.call(arguments);
              __remix_error(args.map(function(a) {
                return typeof a === 'object' ? JSON.stringify(a) : String(a);
              }).join(' '));
            },
            warn: function() { console.log.apply(console, arguments); },
            info: function() { console.log.apply(console, arguments); }
          };

          // Prevent access to dangerous globals
          var require = undefined;
          var process = undefined;
          var global = undefined;
          var globalThis = this;
        JS
      end

      def serialize_result(result)
        case result
        when nil
          nil
        when Numeric, String, TrueClass, FalseClass
          result
        when Hash, Array
          # Already JSON-compatible
          result
        else
          result.to_s
        end
      end

      def js_type_name(result)
        case result
        when nil then 'undefined'
        when Numeric then 'number'
        when String then 'string'
        when TrueClass, FalseClass then 'boolean'
        when Hash then 'object'
        when Array then 'array'
        else 'unknown'
        end
      end

      def clean_error(msg)
        # Remove internal V8 stack traces, keep the useful part
        msg.to_s.lines.first(3).join.strip
      end
    end
  end
end
