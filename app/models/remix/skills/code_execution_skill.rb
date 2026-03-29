module Remix
  module Skills
    class CodeExecutionSkill < BaseSkill
      def self.name = 'code_execution'
      def self.description = 'Help with evaluating and testing code snippets in a sandboxed JavaScript environment'

      def self.triggers
        ['evaluate', 'execute', 'run code', 'test code', 'javascript', 'regex', 'json transform',
         'transform data', 'parse json', 'compute', 'calculate', 'prototype', 'sandbox',
         'try this code', 'code snippet']
      end

      def self.context(user)
        <<~CONTEXT
          ## Code Execution Guide

          ### The `evaluate_code` Tool
          You have access to a sandboxed JavaScript (V8) environment via `evaluate_code`.
          This is useful for:
          - **Data transformation prototyping**: Test transformations before applying them in a JavaScriptAgent
          - **JSON manipulation**: Parse, reshape, or filter JSON data
          - **Regex testing**: Validate regular expressions against sample input
          - **Computing values**: Calculate aggregations, date math, string processing
          - **Validating logic**: Test Liquid-like template logic patterns in JS

          ### Capabilities
          - Full ES6+ JavaScript support (V8 engine)
          - `console.log()` and `console.error()` capture output
          - The last expression is returned as the result
          - Max execution time: 10 seconds (default: 5 seconds)
          - Max memory: 32MB heap
          - No file system, network, or Huginn system access

          ### Best Practices
          - Use `evaluate_code` to prototype logic before embedding it in a JavaScriptAgent's `code` option
          - When a user asks you to test a regex, run it with `evaluate_code` against their sample data
          - For data transformations, demonstrate the input → output mapping with real examples
          - If code fails, explain the error and offer a corrected version
          - Use `console.log()` for intermediate debugging output

          ### Example Patterns

          **Test a regex:**
          ```javascript
          var pattern = /price:\\s*\\$([\\d.]+)/i;
          var text = "The price: $29.99 is final";
          var match = text.match(pattern);
          match ? { matched: true, price: match[1] } : { matched: false };
          ```

          **Transform JSON:**
          ```javascript
          var events = [
            { name: "Alice", score: 85 },
            { name: "Bob", score: 92 },
            { name: "Charlie", score: 78 }
          ];
          events.filter(e => e.score > 80).map(e => ({ ...e, grade: 'A' }));
          ```

          **Prototype JavaScriptAgent logic:**
          ```javascript
          // Simulating what a JavaScriptAgent would do
          var event = { url: "https://example.com/page?id=123&type=alert" };
          var url = new URL(event.url);
          var params = {};
          url.searchParams.forEach(function(v, k) { params[k] = v; });
          params;
          ```
        CONTEXT
      end
    end
  end
end
