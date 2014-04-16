module Agents
  class CommandAgent < Agent
    

    default_schedule "midnight"


    description <<-MD
      The CommandAgent can execute commands on your local system, returning the output.

      `command` specifies the command to be executed, and `path` will tell CommandAgent in what directory to run this command.

      `expected_update_period_in_days` is used to determine if the Agent is working.

      CommandAgent can also act upon recieveing events. These events may contain their own path and command arguments. If they do not, CommandAgent will use the configured options. For this reason, please specify defaults even if you are planning to have this Agent respond to events.

      The resulting event will contain the `command` which was executed, the `path` it was executed under, the `exit_status` of the command, and the actual `output`. CommandAgent will not log an error if the `exit_status` implies that something went wrong.

    MD

    event_description <<-MD
    Events look like this:

      {
        'command' => 'pwd',
        'path' => '/home/Huginn',
        'exit_status' => '0',
        'output' => '/home' 
      }
    MD

    def default_options
      {
          'path' => "/home",
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
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def exec_command(opts = options)
      command = opts['command'] || options['command']
      path = opts['path'] || options['path']

      result = nil
      proc_stat = nil
      Dir.chdir(path){
        result = `#{command}`
        proc_stat = $?
      }

      exit_status = -404 # should never happen, but $? is global
      exit_status = proc_stat.to_i if(proc_stat.is_a?(Process::Status))

      result.chomp! if !result.nil?

      vals = {"command" => command, "path" => path, "exit_status" => exit_status, "output" => result}
      evnt = create_event :payload => vals

      log("Ran '#{command}' under '#{path}'", :outbound_event => evnt)
    end


    def receive(incoming_events)
      incoming_events.each do |event|
        exec_command(event.payload)
      end
    end

    def check
      exec_command(options)
    end


  end
end
