require 'rails_helper'
require 'capybara/rails'
require 'capybara-select-2'

CAPYBARA_TIMEOUT = ENV['CI'] == 'true' ? 60 : 5

# Register a headless Chrome driver with Docker-compatible options
Capybara.register_driver :selenium_chrome_headless_docker do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

if ENV['USE_HEADED_CHROME']
  Capybara.javascript_driver = :selenium_chrome
elsif ENV['DOCKER'] == 'true'
  Capybara.javascript_driver = :selenium_chrome_headless_docker
else
  Capybara.javascript_driver = :selenium_chrome_headless
end
Capybara.default_max_wait_time = CAPYBARA_TIMEOUT

RSpec.configure do |config|
  config.include Warden::Test::Helpers
  config.include AlertConfirmer, type: :feature
  config.include FeatureHelpers, type: :feature

  config.before(:suite) do
    Warden.test_mode!
  end

  config.after(:each) do
    Warden.test_reset!
  end
end

VCR.configure do |config|
  config.ignore_localhost = true
end
