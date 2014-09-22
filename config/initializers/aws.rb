if defined?(RTurk) && !Rails.env.test?
  RTurk::logger.level = Logger::DEBUG
  RTurk.setup(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_ACCESS_KEY'], :sandbox => ENV['AWS_SANDBOX'] == "true")
end
