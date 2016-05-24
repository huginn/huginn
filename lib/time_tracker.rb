class TimeTracker
  attr_accessor :elapsed_time, :result

  def self.track
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    new(Process.clock_gettime(Process::CLOCK_MONOTONIC) - start, result)
  end

  def initialize(elapsed_time, result)
    @elapsed_time = elapsed_time
    @result = result
  end

  def method_missing(method_sym, *arguments, &block)
    if @result.respond_to?(method_sym)
      @result.send(method_sym, *arguments, &block)
    else
      super
    end
  end
end
