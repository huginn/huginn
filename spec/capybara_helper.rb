require 'rails_helper'
require 'capybara/rails'
require 'capybara/poltergeist'
require 'capybara-select2'

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, timeout: 60)
end

Capybara.javascript_driver = :poltergeist
Capybara.default_max_wait_time = 60

RSpec.configure do |config|
  config.include Warden::Test::Helpers
  config.before :suite do
    Warden.test_mode!
  end

  config.after :each do
    Warden.test_reset!
  end
end

VCR.configure do |config|
  config.ignore_localhost = true
end
