require 'cgi'
require 'json'
require 'rufus-scheduler'
require 'pp'
require 'twitter'

class AgentRunner
  @@agents = []

  def initialize(options = {})
    @workers = {}
    @signal_queue = []
    @options = options
    @options[:only] = [@options[:only]].flatten if @options[:only]
    @options[:except] = [@options[:except]].flatten if @options[:except]
    @mutex = Mutex.new
    @scheduler = Rufus::Scheduler.new(frequency: ENV['SCHEDULER_FREQUENCY'].presence || 0.3)

    @scheduler.every 5 do
      restart_dead_workers if @running
    end

    @scheduler.every 60 do
      run_workers if @running
    end

    set_traps
  end

  def stop
    puts "Stopping AgentRunner..." unless Rails.env.test?
    @running = false
    @workers.each_pair do |_, w| w.stop! end
    @scheduler.stop
  end

  def run
    @running = true
    run_workers

    while @running
      if signal = @signal_queue.shift
        handle_signal(signal)
      end
      sleep 0.25
    end
    @scheduler.join
  end

  def set_traps
    %w(INT TERM QUIT).each do |signal|
      Signal.trap(signal) { @signal_queue << signal }
    end
  end

  def self.register(agent)
    @@agents << agent unless @@agents.include?(agent)
  end

  def self.with_connection
    ActiveRecord::Base.connection_pool.with_connection do
      yield
    end
  end

  private

  def run_workers
    workers             = load_workers
    new_worker_ids      = workers.keys
    current_worker_ids  = @workers.keys

    (current_worker_ids - new_worker_ids).each do |outdated_worker_id|
      puts "Killing #{outdated_worker_id}" unless Rails.env.test?
      @workers[outdated_worker_id].stop!
      @workers.delete(outdated_worker_id)
    end

    (new_worker_ids - current_worker_ids).each do |new_worker_id|
      puts "Starting #{new_worker_id}" unless Rails.env.test?
      @workers[new_worker_id] = workers[new_worker_id]
      @workers[new_worker_id].setup!(@scheduler, @mutex)
      @workers[new_worker_id].run!
    end
  end

  def load_workers
    workers = {}
    @@agents.each do |klass|
      next if @options[:only] && !@options[:only].include?(klass)
      next if @options[:except] && @options[:except].include?(klass)

      AgentRunner.with_connection do
        (klass.setup_worker || [])
      end.each do |agent_worker|
        workers[agent_worker.id] = agent_worker
      end
    end
    workers
  end

  def restart_dead_workers
    @workers.each_pair do |id, worker|
      if !worker.restarting && worker.thread && !worker.thread.alive?
        puts "Restarting #{id.to_s}" unless Rails.env.test?
        @workers[id].run!
      end
    end
  end

  def handle_signal(signal)
    case signal
    when 'INT', 'TERM', 'QUIT'
      stop
    end
  end
end

require 'agents/twitter_stream_agent'
require 'agents/jabber_agent'
require 'agents/local_file_agent'
require 'huginn_scheduler'
require 'delayed_job_worker'
