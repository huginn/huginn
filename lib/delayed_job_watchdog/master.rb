# frozen_string_literal: true

require "delayed/master"
require_relative "../delayed_job_watchdog"

module DelayedJobWatchdog
  # Adapts delayed_job_master's fork and shutdown lifecycle to supervised workers.
  module Master
    FORK_MUTEX = Mutex.new
    @channels = []

    class << self
      attr_reader :channels
    end

    # Drain children with their monitors intact before shutting down or execing.
    module Core
      def run
        super
        exec(*([$0] + ARGV)) if @watchdog_restart
      end

      def stop
        @watchdog_restart = false
        graceful_stop
      end

      def restart
        @watchdog_restart = true
        graceful_stop
      end

      def quit
        @watchdog_restart = false
        @signaler.dispatch(:KILL)
        @stop = true
      end
    end

    # Close inherited sibling pipes so only the owning parent can acknowledge work.
    module Forker
      def call(worker)
        raise ArgumentError, "watchdog requires one thread per worker" unless worker.setting.max_threads == 1

        deadlines = [worker.setting.max_run_time || Delayed::Worker.max_run_time,
                     ENV.fetch("DELAYED_JOB_SHUTDOWN_GRACE", "10")]
        unless deadlines.all? { |value| Float(value).finite? && Float(value).positive? }
          raise ArgumentError, "watchdog deadlines must be positive and finite"
        end

        FORK_MUTEX.synchronize do
          upstream_reader, upstream_writer = IO.pipe
          downstream_reader, downstream_writer = IO.pipe
          parent = Channel.new(upstream_reader, downstream_writer)
          @watchdog_child = Channel.new(downstream_reader, upstream_writer)
          worker.instance_variable_set(:@watchdog_channel, parent)
          Master.channels << parent
          begin
            super
          rescue Exception # rubocop:disable Lint/RescueException -- also close pipes on interrupted fork
            Master.channels.delete(parent)
            parent.close
            raise
          ensure
            @watchdog_child.close
          end
        end
      end

      private

      def after_fork_at_child(worker)
        Master.channels.each(&:close)
        super
      end

      def create_instance(worker)
        super.tap do |instance|
          instance.watchdog_client = Client.new(@watchdog_child, instance)
        end
      end
    end

    # Replace the child's ordinary waitpid thread with a bounded supervisor.
    module Monitoring
      private

      def wait_pid(worker)
        channel = worker.instance_variable_get(:@watchdog_channel)
        return super unless channel

        begin
          Supervisor.new(worker.pid, channel,
                         runtime: worker.setting.max_run_time || Delayed::Worker.max_run_time,
                         grace: ENV.fetch("DELAYED_JOB_SHUTDOWN_GRACE", "10"),
                         logger: @master.logger).run
        ensure
          FORK_MUTEX.synchronize do
            Master.channels.delete(channel)
          end
          @master.workers.delete(worker)
        end
      end
    end
  end
end

Delayed::Master::Forker.prepend(DelayedJobWatchdog::Master::Forker)
Delayed::Master::Monitoring.prepend(DelayedJobWatchdog::Master::Monitoring)
Delayed::Master::Core.prepend(DelayedJobWatchdog::Master::Core)
