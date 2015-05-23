module DryRunnable
  def dry_run!
    readonly!

    class << self
      prepend Sandbox
    end

    log = StringIO.new
    @dry_run_logger = Logger.new(log)
    @dry_run_results = {
      events: [],
    }

    begin
      raise "#{short_type} does not support dry-run" unless can_dry_run?
      check
    rescue => e
      error "Exception during dry-run. #{e.message}: #{e.backtrace.join("\n")}"
    end

    @dry_run_results.update(
      memory: memory,
      log: log.string,
    )
  end

  def dry_run?
    is_a? Sandbox
  end

  module Sandbox
    attr_accessor :results

    def logger
      @dry_run_logger
    end

    def save
      valid?
    end

    def save!
      save or raise ActiveRecord::RecordNotSaved
    end

    def log(message, options = {})
      case options[:level] || 3
      when 0..2
        sev = Logger::DEBUG
      when 3
        sev = Logger::INFO
      else
        sev = Logger::ERROR
      end

      logger.log(sev, message)
    end

    def create_event(event_hash)
      if can_create_events?
        @dry_run_results[:events] << event_hash[:payload]
        events.build({ user: user, expires_at: new_event_expiration_date }.merge(event_hash))
      else
        error "This Agent cannot create events!"
      end
    end
  end
end
