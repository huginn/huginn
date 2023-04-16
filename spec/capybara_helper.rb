require 'rails_helper'
require 'capybara/rails'
require 'capybara-select-2'

CAPYBARA_TIMEOUT = ENV['CI'] == 'true' ? 60 : 5

Capybara.javascript_driver = ENV['USE_HEADED_CHROME'] ? :selenium_chrome : :selenium_chrome_headless
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
