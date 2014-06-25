module SpecHelpers
  module TwitterCredentials
    def self.included(klass)
      klass.class_eval do 
        RSpec.configure do |config|
          config.before(:each) do 
            any_instance_of(Twitter::REST::Client) do |klass|
              stub(klass).verify_credentials { 'true' }
            end
          end
        end
      end
    end
  end
end
