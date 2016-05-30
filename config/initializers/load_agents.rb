# This is not strictly needed in the 'production' env because all models are eager loaded
# 'dev' and 'test' have eager loading turned off by default
agent_files = File.join(File.dirname(__FILE__), '..', '..', 'app', 'models', 'agents', '*.rb')
Dir[agent_files].each {|file| require file }
