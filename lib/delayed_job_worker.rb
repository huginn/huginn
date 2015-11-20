class DelayedJobWorker < LongRunnable::Worker
  include LongRunnable

  def run
    @dj = Delayed::Worker.new
    @dj.start
  end

  def stop
    @dj.stop if @dj
  end

  def self.setup_worker
    [new(id: self.to_s)]
  end
end
