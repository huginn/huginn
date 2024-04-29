# Automatically restore `ENV` to its original state after

if defined?(RSpec.configure)
  RSpec.configure do |config|
    # Save ENV before the suite starts
    config.before(:suite) { Dotenv.save }

    # Restore ENV after each example
    config.after { Dotenv.restore }
  end
end

if defined?(ActiveSupport)
  ActiveSupport.on_load(:active_support_test_case) do
    ActiveSupport::TestCase.class_eval do
      # Save ENV before each test
      setup { Dotenv.save }

      # Restore ENV after each test
      teardown do
        Dotenv.restore
      rescue ThreadError => e
        # Restore will fail if running tests in parallel.
        warn e.message
        warn "Set `config.dotenv.autorestore = false` in `config/initializers/test.rb`" if defined?(Dotenv::Rails)
      end
    end
  end
end
