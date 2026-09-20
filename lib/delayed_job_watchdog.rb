# frozen_string_literal: true

require "json"
require "securerandom"

# Supervises one execution at a time without depending on the job database.
module DelayedJobWatchdog
  # Agent-level StandardError handlers must not swallow supervisor cancellation.
  class Cancelled < Exception; end # rubocop:disable Lint/InheritException
  class ProtocolError < StandardError; end
  class ReadTimeout < StandardError; end

  def self.now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def self.current
    Thread.current[:delayed_job_watchdog]
  end

  # A bounded JSON stream over a pair of private, unidirectional pipes.
  class Channel
    LIMIT = 4096

    def initialize(reader, writer)
      @reader = reader
      @writer = writer
      @buffer = +""
    end

    def send(message, timeout: 2)
      data = JSON.generate(message) << "\n"
      raise ProtocolError, "watchdog message too large" if data.bytesize > LIMIT

      deadline = DelayedJobWatchdog.now + timeout
      until data.empty?
        remaining = deadline - DelayedJobWatchdog.now
        raise ProtocolError, "watchdog send timed out" if remaining <= 0 || !IO.select(nil, [@writer], nil, remaining)

        size = @writer.write_nonblock(data, exception: false)
        data = data.byteslice(size..) unless size == :wait_writable
      end
    end

    def receive(timeout: nil)
      deadline = DelayedJobWatchdog.now + timeout if timeout
      loop do
        if (newline = @buffer.index("\n"))
          message = JSON.parse(@buffer.slice!(0..newline))
          raise ProtocolError, "invalid watchdog message" unless message.is_a?(Hash)

          return message
        end
        raise ProtocolError, "watchdog message too large" if @buffer.bytesize >= LIMIT

        remaining = deadline && deadline - DelayedJobWatchdog.now
        raise ReadTimeout if remaining && remaining <= 0
        raise ReadTimeout unless IO.select([@reader], nil, nil, remaining)

        data = @reader.read_nonblock(LIMIT - @buffer.bytesize, exception: false)
        raise EOFError unless data

        @buffer << data unless data == :wait_readable
      end
    rescue JSON::ParserError
      raise ProtocolError, "invalid watchdog JSON"
    end

    def close
      [@reader, @writer].each { |io| io.close unless io.closed? }
    end
  end

  # Keeps cancellation scoped to the execution acknowledged by the parent.
  class Client
    def initialize(channel, worker)
      @channel = channel
      @worker = worker
      @mutex = Mutex.new
      @replies = Queue.new
      @retiring = false
    end

    def start
      @listener = Thread.new do
        loop do
          message = @channel.receive
          message["event"] == "cancel" ? cancel(message["token"]) : @replies.push(message)
        end
      rescue IOError, SystemCallError, ProtocolError
        # Without a supervisor, continuing a possibly stuck job is unsafe.
        Process.exit!(1) unless @closed
      end
    end

    def perform
      raise ProtocolError, "worker is retiring" if @retiring

      @token = SecureRandom.hex(16)
      Thread.current[:delayed_job_watchdog] = self
      request("start")
      started = true
      yield
    ensure
      Thread.current[:delayed_job_watchdog] = nil
      @worker.stop if @retiring
      request("finish") if started
      @token = nil
    end

    def interruptible(&operation)
      Thread.handle_interrupt(Cancelled => :never) do
        @mutex.synchronize do
          @execution_thread = Thread.current
          raise Cancelled, "worker execution deadline exceeded" if @retiring
        end
        Thread.handle_interrupt(Cancelled => :immediate) { operation.call }
      ensure
        @mutex.synchronize { @execution_thread = nil }
      end
    end

    def notify(event, **data)
      @channel.send(data.merge(event: event, token: @token))
    rescue IOError, SystemCallError, ProtocolError
      @retiring = true
      @worker.stop
      raise
    end

    def close
      @closed = true
      begin
        @channel.send({ event: "stop", token: nil }, timeout: 0.1)
      rescue IOError, SystemCallError, ProtocolError
        nil
      end
      @listener&.kill
      @listener&.join
      @channel.close
    end

    private

    def request(event)
      notify(event)
      reply = @replies.pop(timeout: 2)
      unless reply && reply["event"] == "ack" && reply["token"] == @token && reply["for"] == event
        @retiring = true
        @worker.stop
        raise ProtocolError, "watchdog acknowledgement missing"
      end
    end

    def cancel(token)
      @mutex.synchronize do
        return unless token == @token

        @retiring = true
        @worker.stop
        @execution_thread&.raise(Cancelled, "worker execution deadline exceeded")
      end
    end
  end

  # Owns both deadline enforcement and waitpid, preventing PID reuse races.
  class Supervisor # rubocop:disable Metrics/ClassLength -- keep the child lifecycle and protocol together
    def initialize(pid, channel, runtime:, grace:, logger:)
      @pid = pid
      @channel = channel
      @runtime = Float(runtime)
      @grace = Float(grace)
      raise ArgumentError, "watchdog deadlines must be positive and finite" unless [@runtime, @grace].all? { |value|
        value.finite? && value.positive?
      }

      @logger = logger
      @deadline = DelayedJobWatchdog.now + @runtime
    end

    def run
      reaped = false
      @logs = SizedQueue.new(16)
      logger_thread = Thread.new do
        loop do
          event = @logs.pop
          break unless event

          @logger.warn(event)
        end
      rescue StandardError
        nil
      end
      loop do
        if (exited = Process.waitpid2(@pid, Process::WNOHANG))
          reaped = true
          if @execution
            log(event: "worker_exited", pid: @pid,
                exit_status: exited.last.exitstatus, signal: exited.last.termsig, execution: @execution)
          end
          break
        end

        check_deadline
        begin
          receive(@channel.receive(timeout: 0.05)) unless @broken
        rescue ReadTimeout
          next
        rescue IOError, SystemCallError, ProtocolError => e
          @broken = true
          retire(e.class.name) unless @stopping
        end
        sleep 0.05 if @broken
      end
    rescue Errno::ECHILD
      reaped = true
    ensure
      unless reaped
        begin
          Process.kill(:KILL, @pid)
          Process.waitpid(@pid)
        rescue Errno::ESRCH, Errno::ECHILD
          nil
        end
      end
      @channel.close
      @logs&.close
      logger_thread&.join(0.1)
      logger_thread&.kill
    end

    private

    def log(**event)
      @logs.push(JSON.generate(event), true)
    rescue ThreadError
      nil
    end

    def receive(message)
      event = message.fetch("event")
      token = message.fetch("token")
      case event
      when "stop"
        raise ProtocolError, "worker stopped during execution" if @execution && !@kill_at

        @stopping = true
        @kill_at ||= DelayedJobWatchdog.now + @grace
      when "start"
        raise ProtocolError, "unexpected execution start" if @execution || @kill_at || !token.is_a?(String)

        @execution = { token: token, started_at: DelayedJobWatchdog.now, locks: {} }
        @deadline = DelayedJobWatchdog.now + @runtime
      when "finish"
        verify_token(token)
        @execution = nil unless @kill_at
        @deadline = DelayedJobWatchdog.now + @runtime unless @kill_at
      when "job"
        verify_token(token)
        @execution[:job_id] = Integer(message.fetch("job_id"))
      when "lock_acquired"
        verify_token(token)
        lock = (@execution[:locks][message.fetch("name")] ||= {
          connection_id: message["connection_id"], acquired_at: DelayedJobWatchdog.now, depth: 0,
        })
        lock[:depth] += 1
      when "lock_released"
        verify_token(token)
        name = message.fetch("name")
        lock = @execution[:locks].fetch(name)
        @execution[:locks].delete(name) if (lock[:depth] -= 1).zero?
      else
        raise ProtocolError, "unknown watchdog event"
      end
      @channel.send({ event: "ack", token: token, for: event }, timeout: 0.1) if %w[start finish].include?(event)
    rescue KeyError, ArgumentError, TypeError
      raise ProtocolError, "invalid watchdog event"
    end

    def verify_token(token)
      raise ProtocolError, "unexpected execution token" unless @execution && token == @execution[:token]
    end

    def check_deadline
      if @kill_at
        if DelayedJobWatchdog.now >= @kill_at
          Process.kill(:KILL, @pid)
          @kill_at = Float::INFINITY
        end
      elsif DelayedJobWatchdog.now >= @deadline
        retire("execution deadline exceeded")
      end
    rescue Errno::ESRCH
      nil
    end

    def retire(reason)
      return if @kill_at

      @kill_at = DelayedJobWatchdog.now + @grace
      log(event: "worker_retiring", pid: @pid, reason: reason, execution: @execution)
      if @execution && !@broken
        @channel.send({ event: "cancel", token: @execution[:token] }, timeout: 0.1)
      else
        Process.kill(:TERM, @pid)
      end
    rescue IOError, SystemCallError, ProtocolError
      @broken = true
    end
  end
end
