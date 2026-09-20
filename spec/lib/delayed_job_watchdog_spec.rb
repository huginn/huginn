require "spec_helper"
require "logger"
require "stringio"
require "timeout"
require_relative "../../lib/delayed_job_watchdog"

describe DelayedJobWatchdog do # rubocop:disable Metrics/BlockLength
  def channels
    up_read, up_write = IO.pipe
    down_read, down_write = IO.pipe
    [described_class::Channel.new(up_read, down_write), described_class::Channel.new(down_read, up_write)]
  end

  def supervise(runtime: 0.2, grace: 0.2, logger: nil, &operation)
    parent, child = channels
    result_read, result_write = IO.pipe
    pid = fork {
      parent.close
      result_read.close
      worker = Struct.new(:stopped) do
        def stop
          self.stopped = true
        end
      end.new(false)
      client = described_class::Client.new(child, worker)
      client.start
      begin
        operation.call(client, result_write, worker)
        client.close
        exit! 0
      rescue DelayedJobWatchdog::Cancelled, StandardError => e
        result_write.write(e.class.name)
        client.close
        exit! 1
      end
    }
    child.close
    result_write.close
    log = StringIO.new
    supervisor = described_class::Supervisor.new(pid, parent, runtime: runtime, grace: grace,
                                                              logger: logger || Logger.new(log))
    Timeout.timeout(5) do supervisor.run end
    pid = nil
    [result_read.read, log.string]
  ensure
    if pid
      begin
        Process.kill(:KILL, pid)
        Process.waitpid(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end
    end
    parent&.close
    child&.close
    result_read&.close
    result_write&.close unless result_write&.closed?
  end

  it "acknowledges consecutive executions without retiring a healthy worker" do
    output, log = supervise(runtime: 2) { |client, pipe, worker|
      3.times do client.perform { pipe.write("done ") } end
      pipe.write(worker.stopped.to_s)
    }
    expect(output).to eq("done done done false")
    expect(log).to be_empty
  end

  it "interrupts an expired execution, runs ensure and retires the worker" do
    output, log = supervise { |client, pipe, worker|
      begin
        client.perform do
          client.notify("job", job_id: 42)
          client.notify("lock_acquired", name: "agent:7", connection_id: 123)
          client.interruptible do
            sleep 10
          ensure
            pipe.write("ensure ")
          end
        end
      rescue DelayedJobWatchdog::Cancelled
        pipe.write(worker.stopped.to_s)
      end
    }
    expect(output).to eq("ensure true")
    expect(log).to include('"job_id":42', '"connection_id":123', "execution deadline exceeded")
  end

  it "kills a worker that cannot handle the cancellation request" do
    output, log = supervise { |client, pipe, _worker|
      client.perform do
        pipe.write("started")
        Process.kill(:STOP, Process.pid)
      end
    }
    expect(output).to eq("started")
    expect(log).to include("execution deadline exceeded")
  end

  it "keeps the hard deadline when cleanup hangs after cancellation" do
    output, = supervise { |client, pipe, _worker|
      client.perform do
        client.interruptible do
          sleep 10
        ensure
          pipe.write("cleanup")
          sleep 10
        end
      end
    }
    expect(output).to eq("cleanup")
  end

  it "enforces the deadline even if logging is blocked" do
    logger = Object.new
    def logger.warn(_event)
      sleep 30
    end

    output, = supervise(logger: logger) { |client, pipe, _worker|
      client.perform do
        pipe.write("started")
        Process.kill(:STOP, Process.pid)
      end
    }
    expect(output).to eq("started")
  end

  it "does not cancel another execution when a stale token arrives" do
    parent, child = channels
    worker = double(stop: nil)
    client = described_class::Client.new(child, worker)
    client.start
    peer = Thread.new do
      first = parent.receive
      parent.send({ event: "ack", token: first.fetch("token"), for: "start" })
      parent.send({ event: "cancel", token: "previous-execution" })
      last = parent.receive
      parent.send({ event: "ack", token: last.fetch("token"), for: "finish" })
    end
    expect(worker).not_to receive(:stop)
    expect(client.perform { client.interruptible { :ok } }).to eq(:ok)
    peer.join
  ensure
    client&.close
    parent&.close
    peer&.kill
  end

  it "bounds writes when the peer stops reading" do
    parent, child = channels
    expect {
      1000.times { parent.send({ event: "x" * 3000 }, timeout: 0.01) }
    }.to raise_error(DelayedJobWatchdog::ProtocolError, "watchdog send timed out")
  ensure
    parent&.close
    child&.close
  end

  it "rejects oversized messages before writing" do
    parent, child = channels
    expect { parent.send({ event: "x" * 4096 }) }.to raise_error(DelayedJobWatchdog::ProtocolError)
  ensure
    parent&.close
    child&.close
  end

  it "does not execute work until the master acknowledges it" do
    parent, child = channels
    client = described_class::Client.new(child, double(stop: nil))
    client.start
    executed = false
    expect { client.perform { executed = true } }.to raise_error(DelayedJobWatchdog::ProtocolError, /acknowledgement/)
    expect(executed).to be(false)
  ensure
    client&.close
    parent&.close
  end

  it "exits when the parent connection disappears" do
    parent, child = channels
    pid = fork {
      parent.close
      client = described_class::Client.new(child, Object.new)
      client.start
      sleep 10
      exit! 0
    }
    child.close
    parent.close
    _, status = Timeout.timeout(3) { Process.waitpid2(pid) }
    pid = nil
    expect(status.exitstatus).to eq(1)
  ensure
    if pid
      Process.kill(:KILL, pid)
      Process.waitpid(pid)
    end
    parent&.close
    child&.close
  end

  it "reads fragmented and coalesced JSON frames" do
    reader, writer = IO.pipe
    unused_reader, unused_writer = IO.pipe
    channel = described_class::Channel.new(reader, unused_writer)
    writer.write('{"event":')
    expect { channel.receive(timeout: 0.01) }.to raise_error(DelayedJobWatchdog::ReadTimeout)
    writer.write("\"start\"}\n{\"event\":\"finish\"}\n")
    expect(channel.receive.fetch("event")).to eq("start")
    expect(channel.receive.fetch("event")).to eq("finish")
  ensure
    channel&.close
    writer&.close
    unused_reader&.close
  end

  it "rejects malformed and oversized input frames" do
    reader, writer = IO.pipe
    unused_reader, unused_writer = IO.pipe
    channel = described_class::Channel.new(reader, unused_writer)
    writer.write("[]\n")
    expect { channel.receive }.to raise_error(DelayedJobWatchdog::ProtocolError)
    writer.write("x" * described_class::Channel::LIMIT)
    expect { channel.receive }.to raise_error(DelayedJobWatchdog::ProtocolError, /too large/)
  ensure
    channel&.close
    writer&.close
    unused_reader&.close
  end
end
