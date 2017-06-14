module SilencedLogger
  def call(env)
    return super(env) if env['PATH_INFO'] !~ %r{^/worker_status}
    Rails.logger.silence(Logger::ERROR) do
      super(env)
    end
  end
end
Rails::Rack::Logger.send(:prepend, SilencedLogger)
