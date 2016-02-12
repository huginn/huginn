module Agents
  class ShellCommandAgent < Agent
    default_schedule "never"

    can_dry_run!
    no_bulk_receive!


    def self.should_run?
      ENV['ENABLE_INSECURE_AGENTS'] == "true"
    end

    description <<-MD
      The Shell Command Agent will execute commands on your local system, returning the output.

      `command` specifies the command (either a shell command line string or an array of command line arguments) to be executed, and `path` will tell ShellCommandAgent in what directory to run this command.  The content of `stdin` will be fed to the command via the standard input.

      `expected_update_period_in_days` is used to determine if the Agent is working.

      ShellCommandAgent can also act upon received events. When receiving an event, this Agent's options can interpolate values from the incoming event.
      For example, your command could be defined as `{{cmd}}`, in which case the event's `cmd` property would be used.

      The resulting event will contain the `command` which was executed, the `path` it was executed under, the `exit_status` of the command, the `errors`, and the actual `output`. ShellCommandAgent will not log an error if the result implies that something went wrong.

      If `suppress_on_failure` is set to true, no event is emitted when `exit_status` is not zero.

      If `suppress_on_empty_output` is set to true, no event is emitted when `output` is empty.

      *Warning*: This type of Agent runs arbitrary commands on your system, #{Agents::ShellCommandAgent.should_run? ? "but is **currently enabled**" : "and is **currently disabled**"}.
      Only enable this Agent if you trust everyone using your Huginn installation.
      You can enable this Agent in your .env file by setting `ENABLE_INSECURE_AGENTS` to `true`.
    MD

    event_description <<-MD
    Events look like this:

        {
          "command": "pwd",
          "path": "/home/Huginn",
          "exit_status": 0,
          "errors": "",
          "output": "/home/Huginn"
        }
    MD

    def default_options
      {
          'path' => "/",
          'command' => "pwd",
          'suppress_on_failure' => false,
          'suppress_on_empty_output' => false,
          'expected_update_period_in_days' => 1
      }
    end

    def validate_options
      unless options['path'].present? && options['command'].present? && options['expected_update_period_in_days'].present?
        errors.add(:base, "The path, command, and expected_update_period_in_days fields are all required.")
      end

      case options['stdin']
      when String, nil
      else
        errors.add(:base, "stdin must be a string.")
      end

      unless Array(options['command']).all? { |o| o.is_a?(String) }
        errors.add(:base, "command must be a shell command line string or an array of command line arguments.")
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
        stdin = opts['stdin']

        result, errors, exit_status = run_command(path, command, stdin)

        payload = {
          'command' => command,
          'path' => path,
          'exit_status' => exit_status,
          'errors' => errors,
          'output' => result,
        }

        unless suppress_event?(payload)
          created_event = create_event payload: payload
        end

        log("Ran '#{command}' under '#{path}'", outbound_event: created_event, inbound_event: event)
      else
        log("Unable to run because insecure agents are not enabled.  Edit ENABLE_INSECURE_AGENTS in the Huginn .env configuration.")
      end
    end

    def run_command(path, command, stdin)
      begin
        rout, wout = IO.pipe
        rerr, werr = IO.pipe
        rin,  win = IO.pipe

        pid = spawn(*command, chdir: path, out: wout, err: werr, in: rin)

        wout.close
        werr.close
        rin.close

        if stdin
          win.write stdin
          win.close
        end

        (result = rout.read).strip!
        (errors = rerr.read).strip!

        _, status = Process.wait2(pid)
        exit_status = status.exitstatus
      rescue => e
        errors = e.to_s
        result = ''.freeze
        exit_status = nil
      end

      [result, errors, exit_status]
    end

    def suppress_event?(payload)
      (boolify(interpolated['suppress_on_failure']) && payload['exit_status'].nonzero?) ||
        (boolify(interpolated['suppress_on_empty_output']) && payload['output'].empty?)
    end
  end
end
