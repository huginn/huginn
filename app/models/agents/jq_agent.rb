require 'open3'

module Agents
  class JqAgent < Agent
    cannot_be_scheduled!
    can_dry_run!

    def self.should_run?
      !!jq_version
    end

    def self.jq_command
      ENV['USE_JQ'].presence
    end

    def self.jq_version
      if command = jq_command
        Open3.capture2(command, '--version', 2 => IO::NULL).first[/\Ajq-\K\S+/]
      end
    end

    def self.jq_info
      if version = jq_version
        "jq version #{version} is installed"
      else
        "**This agent is not enabled on this server**"
      end
    end

    gem_dependency_check { jq_version }

    description <<-MD
      The Jq Agent allows you to process incoming Events with [jq](https://stedolan.github.io/jq/) the JSON processor. (#{jq_info})

      It allows you to filter, transform and restructure Events in the way you want using jq's powerful features.

      You can specify a jq filter expression to apply to each incoming event in `filter`, and results it produces will become Events to be emitted.

      You can optionally pass in variables to the filter program by specifying key-value pairs of a variable name and an associated value in the `variables` key, each of which becomes a predefined variable.

      This Agent can be used to parse a complex JSON structure that is too hard to handle with JSONPath or Liquid templating.

      For example, suppose that a Post Agent created an Event which contains a `body` key with a value of the JSON formatted string of the following response body:

          {
            "status": "1",
            "since": "1245626956",
            "list": {
              "93817": {
                "item_id": "93817",
                "url": "http://url.com",
                "title": "Page Title",
                "time_updated": "1245626956",
                "time_added": "1245626956",
                "tags": "comma,seperated,list",
                "state": "0"
              },
              "935812": {
                "item_id": "935812",
                "url": "http://google.com",
                "title": "Google",
                "time_updated": "1245635279",
                "time_added": "1245635279",
                "tags": "comma,seperated,list",
                "state": "1"
              }
            }
          }

      Then you could have a Jq Agent with the following jq filter:

          .body | fromjson | .list | to_entries | map(.value) | map(try(.tags |= split(",")) // .) | sort_by(.time_added | tonumber)

      To get the following two Events emitted out of the said incoming Event from Post Agent:

          [
            {
              "item_id": "93817",
              "url": "http://url.com",
              "title": "Page Title",
              "time_updated": "1245626956",
              "time_added": "1245626956",
              "tags": ["comma", "seperated", "list"],
              "state": "0"
            },
            {
              "item_id": "935812",
              "url": "http://google.com",
              "title": "Google",
              "time_updated": "1245626956",
              "time_added": "1245626956",
              "tags": ["comma", "seperated", "list"],
              "state": "1"
            }
          ]
    MD

    def validate_options
      errors.add(:base, "filter needs to be present.") if !options['filter'].is_a?(String)
      errors.add(:base, "variables must be a hash if present.") if options.key?('variables') && !options['variables'].is_a?(Hash)
    end

    def default_options
      {
        'filter' => '.',
        'variables' => {}
      }
    end

    def working?
      self.class.should_run? && !recent_error_logs?
    end

    def receive(incoming_events)
      if !self.class.should_run?
        log("Unable to run because this agent is not enabled.  Edit the USE_JQ environment variable.")
        return
      end

      incoming_events.each do |event|
        interpolate_with(event) do
          process_event(event)
        end
      end
    end

    private

    def get_variables
      variables = interpolated['variables']
      return {} if !variables.is_a?(Hash)

      variables.map { |name, value|
        [name.to_s, value.to_json]
      }.to_h
    end

    def process_event(event)
      Tempfile.create do |file|
        filter = interpolated['filter'].to_s

        # There seems to be no way to force jq to treat an arbitrary
        # string as a filter without being confused with a command
        # line option, so pass one via file.
        file.print filter
        file.close

        variables = get_variables

        command_args = [
          self.class.jq_command,
          '--compact-output',
          '--sort-keys',
          '--from-file', file.path,
          *variables.flat_map { |name, json|
            ['--argjson', name, json]
          }
        ]

        log [
          "Running jq with filter: #{filter}",
          *variables.map { |name, json| "variable: #{name} = #{json}" }
        ].join("\n")

        Open3.popen3(*command_args) do |stdin, stdout, stderr, wait_thread|
          stderr_reader = Thread.new { stderr.read }
          stdout_reader = Thread.new { stdout.each_line.flat_map { |line| JSON.parse(line) } }

          results, errout, status =
            begin
              JSON.dump(event.payload, stdin)
              stdin.close

              [
                stdout_reader.value,
                stderr_reader.value,
                wait_thread.value
              ]
            rescue Errno::EPIPE
            end

          if !status.success?
            error "Error output from jq:\n#{errout}"
            return
          end

          results.keep_if do |result|
            if result.is_a?(Hash)
              true
            else
              error "Ignoring a non-object result: #{result.to_json}"
              false
            end
          end

          log "Creating #{results.size} events"

          results.each do |payload|
            create_event payload: payload
          end
        end
      end
    end
  end
end
