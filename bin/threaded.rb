require 'thread'
require 'huginn_scheduler'

STDOUT.sync = true
STDERR.sync = true

def stop
  puts 'Exiting...'
  @scheduler.stop
  @dj.stop
  @stream.stop
end

def safely(&block)
  begin
    yield block
  rescue StandardError => e
    STDERR.puts "\nException #{e.message}:\n#{e.backtrace.join("\n")}\n\n"
    STDERR.puts "Terminating myself ..."
    STDERR.flush
    stop
  end
end

threads = []
threads << Thread.new do
  safely do
    @stream = TwitterStream.new
    @stream.run
    puts "Twitter stream stopped ..."
  end
end

threads << Thread.new do
  safely do
    @scheduler = HuginnScheduler.new(frequency: ENV['SCHEDULER_FREQUENCY'])
    @scheduler.run!
    puts "Scheduler stopped ..."
  end
end

threads << Thread.new do
  safely do
    require 'delayed/command'
    @dj = Delayed::Worker.new
    @dj.start
    puts "Delayed job stopped ..."
  end
end

# We need to wait a bit to let delayed_job set it's traps so we can override them
sleep 0.5

trap('TERM') do
  stop
end

trap('INT') do
  stop
end

threads.collect { |t| t.join }
