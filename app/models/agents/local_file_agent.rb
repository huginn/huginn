module Agents
  class LocalFileAgent < Agent
    include LongRunnable
    include FormConfigurable
    include FileHandling

    emits_file_pointer!

    default_schedule 'every_1h'

    def self.should_run?
      ENV['ENABLE_INSECURE_AGENTS'] == "true"
    end

    description do
      <<-MD
        The LocalFileAgent can watch a file/directory for changes or emit an event for every file in that directory. When receiving an event it writes the received data into a file.

        `mode` determines if the agent is emitting events for (changed) files or writing received event data to disk.

        ### Reading

        When `watch` is set to `true` the LocalFileAgent will watch the specified `path` for changes, the schedule is ignored and the file system is watched continuously. An event will be emitted for every detected change.

        When `watch` is set to `false` the agent will emit an event for every file in the directory on each scheduled run.

        #{emitting_file_handling_agent_description}

        ### Writing

        Every event will be writting into a file at `path`, Liquid interpolation is possible to change the path per event.

        When `append` is true the received data will be appended to the file.

        Use [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) templating in `data` to specify which part of the received event should be written.

        *Warning*: This type of Agent can read and write any file the user that runs the Huginn server has access to, and is #{Agents::LocalFileAgent.should_run? ? "**currently enabled**" : "**currently disabled**"}.
        Only enable this Agent if you trust everyone using your Huginn installation.
        You can enable this Agent in your .env file by setting `ENABLE_INSECURE_AGENTS` to `true`.
      MD
    end

    event_description do
      "Events will looks like this:\n\n    %s" % if boolify(interpolated['watch'])
        Utils.pretty_print(
          "file_pointer" => {
            "file" => "/tmp/test/filename",
            "agent_id" => id
          },
          "event_type" => "modified/added/removed"
        )
      else
        Utils.pretty_print(
          "file_pointer" => {
            "file" => "/tmp/test/filename",
            "agent_id" => id
          }
        )
      end
    end

    def default_options
      {
        'mode' => 'read',
        'watch' => 'true',
        'append' => 'false',
        'path' => "",
        'data' => '{{ data }}'
      }
    end

    form_configurable :mode, type: :array, values: %w(read write)
    form_configurable :watch, type: :array, values: %w(true false)
    form_configurable :path, type: :string
    form_configurable :append, type: :boolean
    form_configurable :data, type: :string

    def validate_options
      if options['mode'].blank? || !['read', 'write'].include?(options['mode'])
        errors.add(:base, "The 'mode' option is required and must be set to 'read' or 'write'")
      end
      if options['watch'].blank? || ![true, false].include?(boolify(options['watch']))
        errors.add(:base, "The 'watch' option is required and must be set to 'true' or 'false'")
      end
      if options['append'].blank? || ![true, false].include?(boolify(options['append']))
        errors.add(:base, "The 'append' option is required and must be set to 'true' or 'false'")
      end
      if options['path'].blank?
        errors.add(:base, "The 'path' option is required.")
      end
    end

    def working?
      should_run?(false) && ((interpolated['mode'] == 'read' && check_path_existance && checked_without_error?) ||
                             (interpolated['mode'] == 'write' && received_event_without_error?))
    end

    def check
      return if interpolated['mode'] != 'read' || boolify(interpolated['watch']) || !should_run?
      return unless check_path_existance(true)
      if File.directory?(expanded_path)
        Dir.glob(File.join(expanded_path, '*')).select { |f| File.file?(f) }
      else
        [expanded_path]
      end.each do |file|
        create_event payload: get_file_pointer(file)
      end
    end

    def receive(incoming_events)
      return if interpolated['mode'] != 'write' || !should_run?
      incoming_events.each do |event|
        mo = interpolated(event)
        File.open(File.expand_path(mo['path']), boolify(mo['append']) ? 'a' : 'w') do |file|
          file.write(mo['data'])
        end
      end
    end

    def start_worker?
      interpolated['mode'] == 'read' && boolify(interpolated['watch']) && should_run? && check_path_existance
    end

    def check_path_existance(log = true)
      if !File.exist?(expanded_path)
        error("File or directory '#{expanded_path}' does not exist") if log
        return false
      end
      true
    end

    def get_io(file)
      File.open(file, 'r')
    end

    def expanded_path
      @expanded_path ||= File.expand_path(interpolated['path'])
    end

    private

    def should_run?(log = true)
      if self.class.should_run?
        true
      else
        error("Unable to run because insecure agents are not enabled. Set ENABLE_INSECURE_AGENTS to true in the Huginn .env configuration.") if log
        false
      end
    end

    class Worker < LongRunnable::Worker
      def setup
        require 'listen'
        @listener = Listen.to(*listen_options, &method(:callback))
      end

      def run
        sleep unless agent.check_path_existance(true)

        @listener.start
        sleep
      end

      def stop
        @listener.stop
      end

      private

      def callback(*changes)
        AgentRunner.with_connection do
          changes.zip([:modified, :added, :removed]).each do |files, event_type|
            files.each do |file|
              agent.create_event payload: agent.get_file_pointer(file).merge(event_type: event_type)
            end
          end
          agent.touch(:last_check_at)
        end
      end

      def listen_options
        if File.directory?(agent.expanded_path)
          [agent.expanded_path, ignore!: [] ]
        else
          [File.dirname(agent.expanded_path), { ignore!: [], only: /\A#{Regexp.escape(File.basename(agent.expanded_path))}\z/ } ]
        end
      end
    end
  end
end
