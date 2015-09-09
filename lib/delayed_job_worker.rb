class DelayedJobWorker < LongRunnable::Worker
  include LongRunnable

  def run
    @dj = Delayed::Worker.new
    @dj.start
  end

  def stop
    @dj.stop
  end

  def self.setup_worker
    [new(id: self.to_s)]
  end
end
