require 'rails_helper'
require 'capybara/rails'
require 'capybara-select-2'
require 'rspec/retry'

CAPYBARA_TIMEOUT = ENV['CI'] == 'true' ? 60 : 5

def chrome_options(headless:)
  Selenium::WebDriver::Chrome::Options.new.tap do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
    options.add_argument("--window-size=1400,1200")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--no-sandbox")
    options.add_argument("--remote-debugging-pipe")
    options.add_argument("--headless=new") if headless
  end
end

Capybara.register_driver :huginn_selenium_chrome do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: chrome_options(headless: false))
end

Capybara.register_driver :huginn_selenium_chrome_headless do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: chrome_options(headless: true))
end

Capybara.javascript_driver = ENV["USE_HEADED_CHROME"] ? :huginn_selenium_chrome : :huginn_selenium_chrome_headless
Capybara.default_max_wait_time = CAPYBARA_TIMEOUT

RSpec.configure do |config|
  config.include Warden::Test::Helpers
  config.include AlertConfirmer, type: :feature
  config.include FeatureHelpers, type: :feature

  # Retry flaky feature specs (Selenium race conditions, etc.)
  config.verbose_retry = true
  config.display_try_failure_messages = true
  config.around(:each, type: :feature) do |example|
    example.run_with_retry(retry: 3, retry_sleep: 1)
  end

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
