require 'rails_helper'
require 'capybara/rails'
require 'capybara/poltergeist'
require 'capybara-screenshot/rspec'
require 'capybara-select-2'

CAPYBARA_TIMEOUT = ENV['CI'] == 'true' ? 60 : 5

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, timeout: CAPYBARA_TIMEOUT)
end

Capybara.javascript_driver = :poltergeist
Capybara.default_max_wait_time = CAPYBARA_TIMEOUT

Capybara::Screenshot.prune_strategy = { keep: 3 }

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
