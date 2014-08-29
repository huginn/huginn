Rails::Rack::Logger.class_eval do
  def call_with_silence_worker_status(env)
    previous_level = Rails.logger.level
    Rails.logger.level = Logger::ERROR if env['PATH_INFO'] =~ %r{^/worker_status}
    call_without_silence_worker_status(env)
  ensure
    Rails.logger.level = previous_level
  end
  alias_method_chain :call, :silence_worker_status
end
