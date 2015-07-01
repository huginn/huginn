require 'open3'

module Agents
  class ShellCommandAgent < Agent
    default_schedule "never"

    def self.should_run?
      ENV['ENABLE_INSECURE_AGENTS'] == "true"
    end

    description <<-MD
      The ShellCommandAgent can execute commands on your local system, returning the output.

      `command` specifies the command to be executed, and `path` will tell ShellCommandAgent in what directory to run this command.

      `expected_update_period_in_days` is used to determine if the Agent is working.

      ShellCommandAgent can also act upon received events. When receiving an event, this Agent's options can interpolate values from the incoming event.
      For example, your command could be defined as `{{cmd}}`, in which case the event's `cmd` property would be used.

      The resulting event will contain the `command` which was executed, the `path` it was executed under, the `exit_status` of the command, the `errors`, and the actual `output`. ShellCommandAgent will not log an error if the result implies that something went wrong.

      *Warning*: This type of Agent runs arbitrary commands on your system, #{Agents::ShellCommandAgent.should_run? ? "but is **currently enabled**" : "and is **currently disabled**"}.
      Only enable this Agent if you trust everyone using your Huginn installation.
      You can enable this Agent in your .env file by setting `ENABLE_INSECURE_AGENTS` to `true`.
    MD

    event_description <<-MD
    Events look like this:

        {
          "command": "pwd",
          "path": "/home/Huginn",
          "exit_status": "0",
          "errors": "",
          "output": "/home/Huginn"
        }
    MD

    def default_options
      {
          'path' => "/",
          'command' => "pwd",
          'expected_update_period_in_days' => 1
      }
    end

    def validate_options
      unless options['path'].present? && options['command'].present? && options['expected_update_period_in_days'].present?
        errors.add(:base, "The path, command, and expected_update_period_in_days fields are all required.")
      end

      unless File.directory?(options['path'])
        errors.add(:base, "#{options['path']} is not a real directory.")
      end
    end

    def working?
      Agents::ShellCommandAgent.should_run? && event_created_within?(interpolated['expected_update_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        handle(interpolated(event), event)
      end
    end

    def check
      handle(interpolated)
    end

    private

    def handle(opts, event = nil)
      if Agents::ShellCommandAgent.should_run?
        command = opts['command']
        path = opts['path']

        result, errors, exit_status = run_command(path, command)

        vals = {"command" => command, "path" => path, "exit_status" => exit_status, "errors" => errors, "output" => result}
        created_event = create_event :payload => vals

        log("Ran '#{command}' under '#{path}'", :outbound_event => created_event, :inbound_event => event)
      else
        log("Unable to run because insecure agents are not enabled.  Edit ENABLE_INSECURE_AGENTS in the Huginn .env configuration.")
      end
    end

    def run_command(path, command)
      result = nil
      errors = nil
      exit_status = nil

      Dir.chdir(path){
        begin
          stdin, stdout, stderr, wait_thr = Open3.popen3(command)
          exit_status = wait_thr.value.to_i
          result = stdout.gets(nil)
          errors = stderr.gets(nil)
        rescue Exception => e
          errors = e.to_s
        end
      }

      result = result.to_s.strip
      errors = errors.to_s.strip

      [result, errors, exit_status]
    end
  end
end
